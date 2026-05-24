# Screenshot index

Every screenshot in this folder, what it shows, and where in the project it was captured. The README references the most important ones.

## Pipeline (Jenkins)

| File | Description |
|---|---|
| `02-jenkins-pipeline-home.png` | Job home page: 7 builds, test trend, last build 2h 15m ago |
| `05-jenkins-build7-console.png` | Build #7 console output (header) — checkout from GitHub `https://github.com/Sarvagya-10/devsecops-pipeline.git` |
| `06-jenkins-build7-stages.png` | **Hero shot.** Build #7 stage view — all 12 stages green: Checkout SCM, Checkout info, Python setup, Unit tests, SonarQube SAST, Trivy filesystem scan, Docker build, Trivy image scan, ECR login, ECR push, Post Actions. Total 2 min 12 sec. |

## Static analysis (SonarQube 26 Community Build)

| File | Description |
|---|---|
| `01-sonarqube-projects.png` | Projects list. `devsecops-demo` Quality Gate **Passed**, 100% coverage, A grades. |
| `03-sonarqube-overview.png` | Project overview: 59 LoC, Version 0.1.0, Coverage tab, all metrics A. |
| `04-sonarqube-activity.png` | Activity log: 3 analyses, all Quality Gate Passed. |

## Container CVE scan (Trivy)

| File | Description |
|---|---|
| `17-trivy-image-summary-table.png` | Trivy image report summary — debian 13.5 base + 9 Python packages, **0 vulnerabilities** across all. |
| `18-trivy-image-python-pkgs.png` | Python package detail rows from the Trivy report (blinker, click, flask, gunicorn, jinja2, etc.). |
| `19-trivy-image-flask-gunicorn.png` | Trivy report — flask 3.0.3, gunicorn 22.0.0, itsdangerous, jinja2 — all 0 vulns. |
| `20-trivy-image-scan-start.png` | Trivy image scan stage starting on `devsecops-demo:6`. |
| `21-trivy-image-os-detected.png` | Trivy detected the OS layer as Debian 13.5, scans 87 OS packages. |

## Container registry (Amazon ECR)

| File | Description |
|---|---|
| `07-aws-ecr-repository.png` | ECR private repo `devsecops-demo` with image `:latest` + `:7`, AES-256 at rest, push-on-scan enabled. |
| `10-aws-ecr-detail.png` | Zoomed ECR detail — `649966627060.dkr.ecr.us-east-1.amazonaws.com/devsecops-demo`. |

## IAM and identity

| File | Description |
|---|---|
| `08-aws-iam-roles.png` | IAM Roles page showing `devsecops-ec2-role` (EC2 service trust) alongside EKS service-linked roles. |

## Local Kubernetes (Kind, 3-node cluster on the developer laptop)

| File | Description |
|---|---|
| `22-wsl-kind-context-and-apply.png` | `kubectl config use-context kind-devsecops`, then `kubectl get nodes` showing 1 control-plane + 2 workers Ready, then `kubectl apply -k k8s/base/` creating all resources. |
| `23-wsl-kind-rollout-success.png` | Deployment rolled out, 2/2 pods Running, ClusterIP service, HPA, Ingress, NetworkPolicies all created. |

## Cloud Kubernetes (Amazon EKS, one-shot demo)

| File | Description |
|---|---|
| `11-aws-ec2-instances-with-eks-workers.png` | EC2 console — `devsecops-build-server` stopped (t3.micro) plus 2 EKS worker nodes Running (t3.small) during the demo. |
| `12-aws-cloudformation-stacks-eks-active.png` | CloudFormation stacks: `eksctl-devsecops-demo-cluster` and `eksctl-devsecops-demo-nodegroup-workers`, both `CREATE_COMPLETE`. |
| `13-aws-eks-cluster-details.png` | EKS cluster `devsecops-demo` details: API endpoint, OIDC provider URL, Cluster ARN, eks.68 platform version. |
| `14-aws-ec2-instances-list.png` | EC2 instances summary — 4 rows showing the 2 EKS workers Running and the EC2 build server Stopped. |
| `15-aws-eks-cluster-overview.png` | EKS cluster Active, K8s 1.30, cluster health 0 issues, 0 node health issues. |
| `16-aws-eks-cluster-tabs.png` | EKS console tabs: Overview, Resources, Compute, Networking, Add-ons, Capabilities. |
| `24-wsl-eks-create-cluster.png` | `eksctl create cluster` start — region us-east-1, AZs us-east-1d/1b, building CloudFormation stack. |
| `25-wsl-eks-create-complete.png` | Cluster ready — addons created, node group active, `kubectl get nodes -o wide` showing 2 EKS workers Ready. |
| `26-wsl-eks-curl-success.png` | Port-forward + curl of `/health`, `/ready`, `/` returning the live JSON from pods running on EKS, plus `kubectl top pods` showing real CPU/memory. |
| `27-wsl-eks-delete.png` | `eksctl delete cluster` cleanup — CloudFormation stack deletion, AWS load balancers cleaned up. |
| `09-aws-cloudformation-stacks-during-delete.png` | CloudFormation stacks during deletion: nodegroup stack `DELETE_IN_PROGRESS`, cluster stack still `CREATE_COMPLETE`. |
