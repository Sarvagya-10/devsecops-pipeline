# Phase 12 - One-Shot EKS Demo

**This is intentionally short-lived.** EKS costs about $0.14/hour while it exists. Plan to delete it within 60-90 minutes of creation.

## 0. Prerequisites

- `aws` CLI configured with `devsecops_admin` IAM credentials
- `eksctl` installed (>= 0.220)
- `kubectl` already installed

```bash
aws sts get-caller-identity     # confirms which IAM user you are
eksctl version
kubectl version --client | head -1
```

## 1. Create the cluster (~12-15 minutes)

```bash
eksctl create cluster --config-file=infra/eks-optional/cluster.yaml
```

What this does:
- Creates a CloudFormation stack with a new VPC, 3 public + 3 private subnets
- Creates the EKS control plane (managed)
- Creates a managed node group with 2 x t3.small workers
- Adds your IAM user to the cluster's `aws-auth` ConfigMap automatically
- Writes the kubeconfig context `<account>.dkr.ecr.us-east-1.amazonaws.com/devsecops-demo.us-east-1.eksctl.io` (or similar) to `~/.kube/config`

When it finishes:

```bash
kubectl get nodes
kubectl config current-context
```

## 2. Deploy the same manifests we used on Kind

```bash
# Apply the kustomize base (same manifests, no changes needed)
kubectl apply -k k8s/base/

# Wait for the rollout
kubectl -n devsecops rollout status deployment/devsecops-demo --timeout=300s

# Verify
kubectl -n devsecops get pods -o wide
kubectl -n devsecops describe pod -l app.kubernetes.io/name=devsecops-demo | grep -A 5 "Conditions:"
```

> **About the ecr-creds secret**: On EKS, the worker nodes' IAM role already includes
> `AmazonEC2ContainerRegistryReadOnly`, so the kubelet can pull from ECR **without**
> a Kubernetes pull secret. If you see ImagePullBackOff, run `bash local/refresh-ecr-secret.sh`
> as a fallback (works the same way as on Kind).

## 3. Verify the app

```bash
kubectl -n devsecops port-forward svc/devsecops-demo 8081:80 > /tmp/pf.log 2>&1 &
PF_PID=$!
sleep 3

curl http://localhost:8081/health
curl http://localhost:8081/ready
curl http://localhost:8081/

kill $PF_PID
```

Take screenshots of:
- `kubectl get nodes` showing EKS nodes (look at AWS-style instance IDs)
- `kubectl get pods` from EKS
- The curl responses
- The AWS console showing the EKS cluster in `us-east-1`

## 4. **DELETE THE CLUSTER (MANDATORY)**

```bash
eksctl delete cluster --config-file=infra/eks-optional/cluster.yaml --wait
```

Takes ~10-15 minutes. Watch for `CloudFormation stack deletion was completed`.

## 5. Verify nothing is left behind

```bash
# These should all return empty or "no clusters"
aws eks list-clusters --region us-east-1
aws cloudformation list-stacks --region us-east-1 \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[?contains(StackName,'eksctl-devsecops-demo')].StackName"

# Confirm any leftover Load Balancers (shouldn't be any since we did port-forward only)
aws elbv2 describe-load-balancers --region us-east-1 \
    --query "LoadBalancers[?contains(LoadBalancerName,'devsecops')].LoadBalancerName"
```

If any of those return results, finish the cleanup before stopping. Orphan EKS resources cost real money.

## Cost timeline checklist

| Time | Action |
|---|---|
| `t = 0`   | `eksctl create cluster` |
| `t + 15m` | Cluster ready, apply manifests |
| `t + 20m` | Verify + screenshots |
| `t + 25m` | `eksctl delete cluster` |
| `t + 40m` | Cleanup done, total cost ≈ $0.10 |
