# Production-Grade DevSecOps CI/CD Pipeline

A hybrid AWS + local Kubernetes DevSecOps demonstration project.

## Status
Under construction — building phase by phase.

## Architecture
Hybrid: AWS EC2 hosts the CI/CD toolchain (Jenkins, SonarQube, Trivy, Docker); local Minikube hosts the deployed application. Amazon ECR is the container registry; IAM enforces least privilege.

Detailed diagram: `docs/architecture/` (added in Phase 13).

## Tech Stack
- Application: Python 3.12, Flask 3, Gunicorn
- CI/CD: Jenkins
- Security: SonarQube (SAST), Trivy (SCA + container scan)
- Container: Docker, Amazon ECR
- Orchestration: Kubernetes (Minikube local; EKS demo)
- Cloud: AWS (EC2, ECR, IAM)

## Repository Layout
```
app/        Flask application + Dockerfile
ci/         Jenkinsfile and pipeline scripts (Phase 4)
security/   SonarQube and Trivy configuration (Phase 5–6)
k8s/        Kubernetes manifests (Phase 9)
infra/      IAM policies, ECR config (Phase 7, 10)
local/      Minikube configuration (Phase 8)
docs/       Architecture, runbooks, screenshots
```

## Local Development
Build and run the container locally:
```bash
cd app
docker build -t devsecops-demo:local .
docker run --rm -p 8080:8080 devsecops-demo:local
curl http://localhost:8080/health
```

## License
MIT
