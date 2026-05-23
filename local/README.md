# Phase 8 + Phase 9 — Local Kubernetes (Kind)

This folder is the **execution guide for your second PC** (the one with WSL2 + Kind + Docker).
Files here drive the local cluster; manifests live in `../k8s/`.

## Prerequisites (run once)

```bash
# Verify required tooling exists on this PC
docker version | head -5
kind version
kubectl version --client | head -1
aws --version

# Configure AWS CLI with your devsecops_admin IAM user (one time)
aws configure
# - Access key ID / secret: from the IAM user
# - Region:                 us-east-1
# - Output format:          json
aws sts get-caller-identity      # should show user/devsecops_admin
```

## Phase 8 — Create a dedicated Kind cluster

```bash
# git clone (only the first time)
git clone https://github.com/Sarvagya-10/devsecops-pipeline.git
cd devsecops-pipeline

# Spin up a new cluster called 'devsecops' (will not touch your other Kind clusters)
kind create cluster --name devsecops --config local/kind-config.yaml

# Verify
kubectl cluster-info --context kind-devsecops
kubectl get nodes
```

You should see one `control-plane` node and two `worker` nodes.

## Phase 9 — Apply manifests

```bash
# 1. Apply the base manifests (namespace, configmap, deployment, service, hpa, netpol, ingress)
kubectl apply -k k8s/base/

# 2. Refresh the ECR pull secret (token lasts 12 hours - rerun later if pulls start failing)
bash local/refresh-ecr-secret.sh

# 3. Wait for the deployment to roll out
kubectl -n devsecops rollout status deployment/devsecops-demo --timeout=180s

# 4. Verify pods
kubectl -n devsecops get pods -o wide
kubectl -n devsecops describe deployment devsecops-demo | head -30
```

## Phase 9 verify — talk to the app

```bash
# Port-forward to the ClusterIP service
kubectl -n devsecops port-forward svc/devsecops-demo 8080:80 &

# Curl the endpoints
curl -s http://localhost:8080/health
curl -s http://localhost:8080/ready
curl -s http://localhost:8080/

# Stop the port-forward
kill %1
```

You should see the same JSON responses you saw when running the image directly in Phase 4.

## Optional - Ingress (host-based access)

```bash
# Install ingress-nginx for Kind (kind-specific manifests)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
kubectl -n ingress-nginx wait --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s

# Add devsecops.local to your /etc/hosts (or Windows hosts)
echo "127.0.0.1 devsecops.local" | sudo tee -a /etc/hosts

# Then visit http://devsecops.local:8080/ in your browser
```

## Cleanup (when done)

```bash
# Delete the project namespace (keeps the cluster for other work)
kubectl delete namespace devsecops

# OR delete the whole cluster (does not touch your other 2 clusters)
kind delete cluster --name devsecops
```

## Known limitations of this local setup

- **NetworkPolicy enforcement**: Kind's default CNI (kindnet) does not enforce NetworkPolicy rules. The manifest is present for documentation and works on real CNIs like Calico/Cilium. Real production EKS uses Calico or AWS VPC CNI with network policy.
- **HPA**: needs metrics-server (`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`). Without it, HPA shows `unknown`.
- **ECR auth**: 12-hour token. EKS production uses IAM Roles for Service Accounts (IRSA), which eliminates the secret entirely.
