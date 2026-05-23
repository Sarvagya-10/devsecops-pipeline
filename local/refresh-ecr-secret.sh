#!/bin/bash
# Refresh the ecr-creds imagePullSecret in the devsecops namespace.
# ECR auth tokens last 12 hours. Re-run this script whenever pulls start failing.
#
# Real production answer: EKS + IAM Roles for Service Accounts (IRSA),
# which removes the need for this secret entirely. Out of scope for local Kind.
set -euo pipefail

NS="${NS:-devsecops}"
REGION="${REGION:-us-east-1}"
REGISTRY="${REGISTRY:-649966627060.dkr.ecr.us-east-1.amazonaws.com}"

echo "Refreshing ecr-creds in namespace ${NS}..."

# Make sure the namespace exists (idempotent)
kubectl get namespace "${NS}" > /dev/null 2>&1 \
  || kubectl create namespace "${NS}"

# Delete the existing secret if present (so we always start clean)
kubectl -n "${NS}" delete secret ecr-creds --ignore-not-found

# Create a fresh dockerconfigjson secret using a current 12h ECR token
kubectl -n "${NS}" create secret docker-registry ecr-creds \
  --docker-server="${REGISTRY}" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "${REGION}")" \
  --docker-email=ecr@local.invalid

echo "Done. Secret ecr-creds is valid for ~12 hours."
