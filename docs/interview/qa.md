# Interview Prep — Q&A Grounded in This Project

Common DevSecOps / SRE / Platform Engineer interview questions, answered using **this project** as the worked example. Cite specific files and screenshots — concrete > hand-wavy.

Sections:

1. [Architecture & design](#architecture--design)
2. [CI/CD pipeline](#cicd-pipeline)
3. [Security gates](#security-gates)
4. [IAM & secrets](#iam--secrets)
5. [Docker hardening](#docker-hardening)
6. [Kubernetes hardening](#kubernetes-hardening)
7. [Cost optimization](#cost-optimization)
8. [Operational / debug stories](#operational--debug-stories)
9. ["Tell me about a time" prompts](#tell-me-about-a-time-prompts)

---

## Architecture & design

### Q: Walk me through the architecture.

> Developer pushes to GitHub. Jenkins on an EC2 instance polls and starts a 12-stage declarative pipeline. The pipeline runs pytest, then **three security scanners as separate stages** — SonarQube SAST, Trivy filesystem (deps + secrets + IaC misconfig), and Trivy image — each one fails the build on HIGH or CRITICAL findings. If everything passes, the image is pushed to a private Amazon ECR repository. From there, Kubernetes — either local Kind for developer iteration or managed EKS for production-shape demos — pulls the image and runs it. The same Kustomize bundle works for both Kind and EKS with zero changes.

Show: `docs/screenshots/06-jenkins-build7-stages.png` and `docs/architecture/architecture.md`.

### Q: Why hybrid AWS + local, not pure AWS?

> Two reasons: cost discipline and developer iteration speed. Putting Kubernetes on the developer laptop via Kind costs zero and lets me iterate without waiting for an EKS control plane to come up. AWS still owns the build server (EC2), the registry (ECR), and the IAM story, which is what recruiters actually care about. For the production-shape demo, I do spin up real EKS, but only briefly — about 30 minutes — then tear it down. Total project AWS spend stayed under $1.

### Q: Why Kustomize instead of Helm?

> The project is small enough that Helm's templating power isn't earning its complexity yet. Kustomize covers the actual need — base manifests with environment overlays for dev/prod and a clean way to pin the image tag — without introducing a template language. If the project grew to need conditional logic or shared chart distribution, Helm becomes the right answer.

---

## CI/CD pipeline

### Q: What does the pipeline actually do, stage by stage?

> Twelve stages: Checkout from GitHub → log commit info → create a Python venv → run pytest with 100% coverage on `src/` → SonarQube SAST → Trivy filesystem scan → Docker multi-stage build → Trivy image scan → ECR login via instance role → docker tag + push to ECR → workspace cleanup. The security stages are independent — any one failing fails the whole build.

### Q: How does Jenkins talk to Docker if Jenkins is in a container?

> Two things mounted into the Jenkins container: `/var/run/docker.sock` (so `docker build` and `docker push` run on the host daemon) and the Jenkins user is added to the host's docker group via `--group-add` so it has socket permissions. Resulting images live on the host daemon, not inside the Jenkins container, so they survive container restarts.

### Q: Why is the source on GitHub when you also have a bare git repo on EC2?

> GitHub is the public face — the recruiter-visible portfolio URL and the actual source of truth. The bare repo at `/srv/git/devsecops.git` on EC2 is a deliberate demonstration of the air-gapped / enterprise pattern: many regulated environments require source control to live inside the build server, not on a third-party host. Having both shows I understand the tradeoff. Jenkins reads from GitHub in practice; the bare repo is a fallback.

### Q: How would you add deployment to this pipeline?

> Add a "kubectl apply" stage after ECR push, using a Kubernetes service account credential stored in a Jenkins credential. Better: use a GitOps tool like ArgoCD watching the `k8s/` directory, so a new commit to manifests triggers reconciliation rather than Jenkins doing the deploy. The pipeline's job is to produce a vetted image; the cluster's job is to converge to whatever the manifests say.

---

## Security gates

### Q: What stops a bad commit from reaching production?

> Three gates that any one of which fails the build:
> 
> 1. **SonarQube SAST**: reads the source code statically. Looks for bugs, vulnerabilities, code smells, security hotspots. The quality gate is currently "0 issues, coverage above default" — block on any.
> 2. **Trivy filesystem scan**: reads `requirements.txt` to find vulnerable dependencies, scans the entire workspace for hardcoded secrets and IaC misconfigs (Dockerfile rules, K8s rules). Blocks on HIGH or CRITICAL, ignores unfixed.
> 3. **Trivy image scan**: reads the built image's OS layer and language ecosystem. Blocks on HIGH or CRITICAL.
> 
> AWS Inspector adds a fourth scan after the image lands in ECR — that one runs cloud-side and shows up in the ECR console.

### Q: Why `--ignore-unfixed` on Trivy?

> A CVE that has no upstream fix can't be remediated by the developer — there's no version to upgrade to. Failing the build on it forces an indefinite block. We document and accept those via `.trivyignore` instead, with a written reason. Fail loudly on the things we *can* fix.

### Q: How would you handle a CVE that you can't fix and can't accept?

> Three options in order of preference:
> 
> 1. **Patch at the OS layer**: build a custom base image that backports the fix. Expensive but possible.
> 2. **Replace the vulnerable dependency**: e.g., swap `requests` for `httpx` if `requests` has an unpatched CVE.
> 3. **Compensating control**: prove the vulnerable code path is not reachable in our app (call graph analysis), then add to `.trivyignore` with the analysis as evidence. This is the realistic answer in most production environments.

### Q: Sonar + Trivy overlap. Why both?

> They look at different things. SonarQube reads our source code; Trivy reads our dependencies and built artifacts. Sonar will tell us if we wrote a SQL injection; Trivy will tell us if the `Jinja2` version we shipped has a known CVE. Both are needed for shift-left to mean anything.

---

## IAM & secrets

### Q: How does Jenkins authenticate to ECR?

> Through an EC2 instance role. The EC2 instance has an instance profile attached that wraps an IAM role with a managed policy scoped to **one** ECR repository. The Jenkins container reads short-lived credentials from the EC2 metadata service (IMDS) via the AWS CLI's default credential provider chain. No long-lived AWS access keys exist anywhere — not in environment variables, not in Jenkins credentials, not in any file or commit.

Show: `docs/security/iam-review.md`.

### Q: How is the IAM policy "least privilege"?

> Two statements:
> 
> 1. `ecr:GetAuthorizationToken` is `Resource: "*"` because AWS does not allow scoping this action. It's the single documented exception.
> 2. All the actual push/pull actions — `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, `PutImage`, etc. — are scoped to the ARN of one specific repository: `arn:aws:ecr:us-east-1:649966627060:repository/devsecops-demo`.
> 
> I deliberately ran `aws ecr describe-repositories` (no filter) during testing to confirm the gate works. It returned `AccessDenied` because that call targets `*` repositories. The denial proves the scope is enforcing correctly.

### Q: What is IMDSv2 and why did you require it?

> IMDS is the EC2 instance metadata service at `169.254.169.254`. IMDSv2 requires a session token on every request, obtained via a separate `PUT` first. This defeats the SSRF class of attacks where an attacker tricks an application running on the instance into making a `GET 169.254.169.254/...` call — without IMDSv2, that call would return the instance role's credentials. The Capital One 2019 breach was exactly this pattern. We set `HttpTokens=required` on the instance.
> 
> Hop limit 2 was needed because the Jenkins container reaches IMDS through the Docker bridge, which counts as a hop.

### Q: What's in a Kubernetes secret for ECR auth, and what's the limitation?

> The secret is a `docker-registry` type secret. Its data is base64-encoded JSON containing the ECR registry URL, username `AWS`, and a temporary 12-hour token from `aws ecr get-login-password`. The limitation is the 12-hour expiry — a long-lived Kind cluster needs the secret refreshed periodically (we have `local/refresh-ecr-secret.sh`).
> 
> The right production answer is **IAM Roles for Service Accounts (IRSA)** on EKS, which eliminates the secret entirely. EKS worker nodes can assume role-scoped credentials directly via the OIDC provider, and the kubelet pulls from ECR using those credentials. We deliberately left IRSA out of the one-shot demo to keep scope small, but I'd add it in a real production setup.

---

## Docker hardening

### Q: Why a multi-stage Dockerfile?

> The builder stage has pip, gcc-adjacent tooling, source archives — none of which need to ship to production. The runtime stage gets only the installed Python packages and our application code. Net result: image is ~40% smaller, attack surface is dramatically reduced, and the final image has no build tools an attacker could leverage.

### Q: Why non-root, and why UID 10001 specifically?

> Two reasons. First, root in a container can still escalate to host root if a container-escape vulnerability is found — running as non-root is defense-in-depth. Second, Kubernetes Pod Security Standards Restricted profile **requires** non-root with a UID above 10000. Using 10001 lets the same image deploy under the strictest pod-security policy without further changes.

### Q: What does `readOnlyRootFilesystem: true` cost you?

> Anywhere the application or its runtime tries to write fails. For our app, gunicorn writes to `/tmp` for temp files, so we mount an `emptyDir` volume there. PYTHONDONTWRITEBYTECODE=1 prevents `.pyc` writes elsewhere. The constraint forces explicit decisions about every writable path, which is the whole point.

### Q: HEALTHCHECK without curl — why?

> `curl` is a binary. Every binary in the image is one more thing that needs CVE scanning and one more thing an attacker can use after compromise. Python's stdlib `urllib.request` is already in the image (Python is the app runtime), so we use it for the HEALTHCHECK. Smaller image, smaller attack surface, no functional loss.

---

## Kubernetes hardening

### Q: What is the Pod Security Standard "Restricted" and how do you enforce it?

> Three profiles defined by the Kubernetes project: Privileged (legacy, anything goes), Baseline (a few obvious banned settings), and Restricted (the hardened defaults Kubernetes considers minimum-acceptable for production). Restricted requires: non-root, drop all capabilities, no privileged escalation, `runtimeDefault` seccomp, no host network/PID/IPC, read-only root filesystem, and a few more.
> 
> Enforcement is via labels on the namespace:
> 
> ```yaml
> pod-security.kubernetes.io/enforce: restricted
> pod-security.kubernetes.io/warn: restricted
> pod-security.kubernetes.io/audit: restricted
> ```
> 
> The admission controller rejects any pod created in that namespace that violates the profile. Defense-in-depth: even if someone applies a bad manifest, the API server refuses it.

### Q: NetworkPolicy default-deny — does it actually work?

> Depends on the CNI. Kindnet (Kind's default) **does not enforce NetworkPolicy** — the manifests are accepted but have no effect. Calico, Cilium, and AWS VPC CNI with policy support do enforce. So our default-deny + scoped allow manifests are correct, but they only bite on a real cluster. I document this in `local/README.md` so nobody's surprised.

### Q: What does your Role grant?

> Two rules:
> 
> 1. `get`, `watch` on **one specific ConfigMap** (`devsecops-demo-config`) — scoped via `resourceNames`. This is the right shape for a hot-reload config pattern even though the current app doesn't use it.
> 2. `get`, `list` on pods in the **own namespace only**. This is the "self-discovery" shape — the app could list its sibling pods if it ever needed to.
> 
> The deployment sets `automountServiceAccountToken: false` because the app doesn't currently call the Kubernetes API. The SA + Role + RoleBinding exist as scaffolding for the next app that does.

### Q: Why ephemeral-storage requests + limits?

> CPU and memory limits are common; ephemeral-storage limits often forgotten. Without them, a runaway log or a misbehaving temp file can fill the node's disk and kill the kubelet — taking down every pod on that node. We set 64Mi request / 256Mi limit. For a tiny app like this it's mostly preventive, but it's the kind of thing that bites in production at 3am.

---

## Cost optimization

### Q: How did you keep AWS spend under $1?

> Six things, in order of impact:
> 
> 1. **Single EC2 instance** running everything, stopped between sessions. Free Tier covers 750 hours/month — easily within budget when the instance is stopped overnight.
> 2. **Elastic IP** so stopped instances don't shuffle public addresses (the EIP itself is free during Free Tier).
> 3. **Local Kubernetes** (Kind) for everyday iteration — Kubernetes for free.
> 4. **One-shot EKS** demos: spin up, deploy, screenshot, destroy within an hour. Total EKS cost ~$0.10–$0.30.
> 5. **ECR lifecycle policy** auto-expiring untagged images after 1 day and keeping only the 5 newest tagged. Storage cap at almost-zero.
> 6. **No NAT Gateway, no Load Balancer, no RDS, no managed anything else.** Those are the silent $30/mo killers that catch students off-guard.

### Q: What if Free Tier ends?

> The same architecture runs ~$10/month on a t3.micro running 24/7 plus ~$3.65 for the Elastic IP. Stopping the instance overnight cuts that further. The expensive choice is keeping EKS running 24/7 (~$100/month for control plane alone) — we deliberately avoided that.

---

## Operational / debug stories

These are "tell me about a time" gold. Pick the one that fits the question being asked.

### Story 1: Multi-stage Python package path bug

> First deployable build (Build #3) produced an image that crashed immediately with `ModuleNotFoundError: No module named 'gunicorn'`. The Trivy/Sonar gates had passed; this was a runtime-only issue.
> 
> Root cause: `pip install --user` in the builder stage installs packages to `/root/.local`. Our COPY was placing them at `/home/appuser/.local` in the runtime stage. But Python's `USER_SITE` resolves from `$HOME`, and our `useradd` had set the appuser's home to `/app` (because that was also our WORKDIR). So Python was looking for packages at `/app/.local/lib/python3.12/site-packages`, while the packages physically lived at `/home/appuser/.local/lib/python3.12/site-packages`.
> 
> Fix: COPY to `/app/.local`, update the `PATH` env var. Build #4 ran cleanly.
> 
> Lesson: the security gates didn't catch this because the image is technically valid — it just doesn't function. Runtime smoke tests post-build are a useful addition to the pipeline.

### Story 2: SonarQube version warning + community-tag move

> Spun up SonarQube initially with `sonarqube:lts-community`. On first access, SonarQube displayed a banner: *"You're running a version of SonarQube that is no longer active."* The `lts-community` tag was pointing at 9.9, which had reached end-of-active-support.
> 
> Resolution: discovered Sonar had moved to a new `community` tag (then v26.5.0). Pulled fresh, wiped the H2 volume since no real analysis data yet, restarted. Updated `user-data.sh` accordingly so future bootstraps don't repeat the issue.
> 
> Lesson: vendor tag conventions change. Pinning to a specific version (`sonarqube:26.5-community`) is the more durable choice in production.

### Story 3: Kind cluster port collision

> First attempt to create the local Kind cluster failed with: *"Bind for 0.0.0.0:8080 failed: port is already allocated."* My existing local Jenkins container was already binding host port 8080. The default Kind config maps the cluster's ingress port to host 8080.
> 
> Resolution options I considered: switch Kind to a different host port (e.g., 30080/30443), or stop the conflicting Jenkins container. I ended up stopping local Jenkins because the project's "real" Jenkins is the one on EC2. The config could be made more portable by using 30080/30443 by default — I noted that as a future tweak.
> 
> Lesson: Kind's default ingress port (80→8080) collides with common dev tools. Port choices matter for portability.

### Story 4: ECR auth from inside Jenkins container failing initially

> `aws sts get-caller-identity` from inside the Jenkins container initially returned no credentials, even after attaching the IAM instance profile to the EC2.
> 
> Root cause: `HttpPutResponseHopLimit` defaults to 1 on IMDSv2-required instances. A request from inside a Docker container goes container → docker0 bridge → host network → IMDS, which is two hops.
> 
> Fix: `aws ec2 modify-instance-metadata-options --http-put-response-hop-limit 2`. After that, the AWS CLI inside the container immediately picked up the instance-role credentials.
> 
> Lesson: IMDSv2 hop limits are the silent killer of "but I attached the role!" debugging on container-on-EC2 architectures.

---

## "Tell me about a time" prompts

### "...you improved a security posture."

> Use Story 4 + the IAM least-privilege framing. "I switched the Jenkins pipeline from static AWS access keys to instance-role-based auth via IMDSv2, scoped to a single ECR repository. The change involved..."

### "...you reduced cost."

> Cost optimization section. "When I sized the architecture I deliberately chose..."

### "...you debugged a hard problem."

> Story 1 (gunicorn ModuleNotFoundError) is the best one — it shows multi-stage reasoning about Python's USER_SITE resolution, container vs host filesystem, and the discipline to keep going past the obvious "it builds, ship it."

### "...you made a tradeoff."

> Use the local Kind + one-shot EKS decision. "I had a fixed AWS budget and the choice between continuous-EKS — production-realistic — and local Kind — cheap but less impressive on paper. I picked Kind for daily iteration plus a one-hour EKS demo to get both signals."

### "...you wrote production code with security in mind."

> The Dockerfile. Walk through every hardening choice: multi-stage, slim base, non-root, drop caps, read-only FS, no shell, no curl, HEALTHCHECK via stdlib, pinned versions, `.dockerignore` to keep secrets out. Every choice has a "why."
