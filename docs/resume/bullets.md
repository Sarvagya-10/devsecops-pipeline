# Resume + Portfolio Bullets

Curated text you can paste into your resume, LinkedIn, or portfolio. Every claim here is backed by a screenshot in `docs/screenshots/` and code in this repo.

## One-line headline (for portfolio site / GitHub bio)

> Built a production-grade DevSecOps CI/CD pipeline on AWS with shift-left security (SonarQube + Trivy), IAM least-privilege, and multi-target Kubernetes deploy (Kind + EKS).

## One-paragraph project description (LinkedIn About / cover letter)

> Designed and built an end-to-end DevSecOps pipeline that ships a containerized Flask application through 12 automated stages: unit tests with 100% coverage, SonarQube SAST, Trivy filesystem and image vulnerability scans, multi-stage hardened Docker build, and authenticated push to a private Amazon ECR repository — all gated by HIGH/CRITICAL severity thresholds that block the build before any image leaves the CI runner. Deploys the same Kustomize bundle to local Kind for developer iteration and to managed Amazon EKS for production-shape demos, with zero application changes between environments. Enforces the Kubernetes Restricted Pod Security Standard, non-root containers (UID 10001), `readOnlyRootFilesystem`, dropped capabilities, scoped IAM role auth via IMDSv2 (no static AWS keys), and NetworkPolicy default-deny. Total AWS spend kept under $1 through Free-Tier sizing and one-shot EKS demos.

## Resume — long form (5 bullets, ~25-30 words each)

> **Production-Grade DevSecOps CI/CD Pipeline on AWS** — *personal project, 2026*
> 
> - Designed a 12-stage Jenkins pipeline with three security gates (SonarQube SAST, Trivy filesystem, Trivy image) that fail the build on HIGH/CRITICAL findings — blocked every image with known CVEs from reaching the registry.
> - Implemented IAM least-privilege using an EC2 instance role scoped to **one** ECR repository; verified the policy by deliberately triggering `AccessDenied` on broader actions — no static AWS keys exist in any commit, container, or Jenkins config.
> - Authored hardened multi-stage Dockerfile (Python 3.12-slim, non-root UID 10001, `readOnlyRootFilesystem`, drop-all capabilities, stdlib HEALTHCHECK) compliant with the Kubernetes Restricted Pod Security Standard — image passes Trivy and AWS Inspector scans with **0 CVEs**.
> - Wrote portable Kustomize manifests (Deployment, Service, HPA, Ingress, NetworkPolicy, RBAC) deployed identically to local Kind cluster and managed Amazon EKS — proved environment-parity through `kubectl apply -k` without per-target overrides.
> - Cost-engineered for AWS Free Tier: stop-on-idle EC2, ECR lifecycle policy auto-expiring untagged images, one-shot EKS demo with mandatory teardown verification — kept total project AWS spend under $1.

## Resume — short form (3 bullets, ~20 words each)

> - Built end-to-end DevSecOps pipeline on AWS (Jenkins, SonarQube, Trivy, ECR, EKS) with shift-left security gates blocking HIGH/CRITICAL CVEs before image push.
> - Hardened images and Kubernetes manifests to the Restricted Pod Security Standard with non-root UID, read-only root FS, dropped capabilities, NetworkPolicy default-deny, and scoped IAM least-privilege.
> - Demonstrated multi-target deploy by applying the same Kustomize bundle to local Kind and managed Amazon EKS — zero application changes; total AWS spend kept under $1 via Free-Tier sizing.

## LinkedIn featured project blurb

> **Production-Grade DevSecOps CI/CD Pipeline on AWS**
> 
> Hybrid AWS + local-Kubernetes pipeline that demonstrates shift-left security, least-privilege IAM, and multi-target deploy. Twelve Jenkins stages gate every commit through SAST (SonarQube), dependency + secret scanning (Trivy fs), container image scanning (Trivy image), and AWS Inspector. The same Kustomize bundle deploys to local Kind for iteration and to managed Amazon EKS for production-shape demos.
> 
> Stack: Python, Flask, Docker (multi-stage, non-root), Jenkins, SonarQube, Trivy, Amazon ECR (private, AES-256, scan-on-push), Amazon EKS, Kind, AWS IAM (instance roles, IMDSv2), Kubernetes RBAC, NetworkPolicy.
> 
> Repo: github.com/Sarvagya-10/devsecops-pipeline

## Skills section keywords (paste into the keyword block)

```
DevSecOps · CI/CD · Jenkins · SonarQube · Trivy · Aqua Security · SAST · SCA ·
Docker · Kubernetes · Kustomize · Kind · Amazon EKS · Amazon ECR · IAM ·
AWS · EC2 · IMDSv2 · STS · CloudFormation · eksctl · Pod Security Standards ·
RBAC · NetworkPolicy · Least Privilege · Shift-Left Security · Python · Flask ·
Linux · Bash · pytest · Git · GitHub
```

## What to lead with in interviews

When a recruiter asks "tell me about a project," lead with:

> "I built an end-to-end DevSecOps pipeline that gates every code change through three security scanners before the image reaches the registry. The interesting part isn't that the scanners run — it's that I wired up the gates so a HIGH or CRITICAL finding blocks the build entirely, and I scoped the AWS credentials so the pipeline can only push to one specific ECR repository. I can show you the policy and the failed-build screenshot if you want."

Then **stop talking** and let them pick which thread to pull on.
