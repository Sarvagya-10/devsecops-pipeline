# IAM Least-Privilege Review

This document explains every IAM resource the project creates, what it's allowed to do, and why each scope decision was made. It is the **Phase 10** artifact of the DevSecOps pipeline.

## Principle

> The pipeline must run with the **smallest set of AWS permissions** that lets it succeed, **and no more**. A leaked credential in this project should compromise only the resources the credential needs — never the whole AWS account.

## Resources we created

| Resource | Type | Purpose |
|---|---|---|
| `devsecops_admin` | IAM user | The human operator (project owner) |
| `devsecops-ec2-role` | IAM role | Identity assumed by the EC2 build server |
| `devsecops-ecr-push-policy` | Managed policy | Permissions attached to the role |
| `devsecops-ec2-profile` | Instance profile | Wrapper that lets EC2 assume the role |

## 1. `devsecops_admin` IAM user (human)

**Attached policy**: `AdministratorAccess` (AWS-managed).

### Why admin is acceptable here

- This is the **project owner's** identity, not a service identity
- Used interactively from a local laptop with MFA-protected console access
- Used to create/destroy AWS resources during phases 3, 7, 12 etc.
- An admin policy for the human is the equivalent of "I own this AWS account"

### What would change in a real org

In a production team, this would split into:
- A read-only audit user for daily work
- A short-lived assumed role for resource creation (via STS `assume-role` with MFA)
- A break-glass admin used only for incidents

For a single-person learning account, the simpler model is acceptable.

## 2. `devsecops-ec2-role` (service identity)

This is the role the EC2 build server assumes. It is what the Jenkins pipeline uses to push images to ECR — **no static AWS keys live in Jenkins or in any file**.

### Trust policy (who can assume the role)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

**Scope**: only the EC2 service (any EC2 instance with the right instance profile attached) can assume this role. No other AWS service, no other AWS account, no IAM user.

### Permissions (attached policy `devsecops-ecr-push-policy`)

Full JSON in `infra/iam/ecr-push-policy.json`. Two statements:

#### Statement 1 — `ecr:GetAuthorizationToken`

| Field | Value | Why |
|---|---|---|
| Action | `ecr:GetAuthorizationToken` | Get the 12-hour ECR auth token used by `docker login` |
| Resource | `*` | AWS does not allow scoping this action to a specific repo (token is account-wide). This is the **only** action with `*` — accepted as a documented exception. |

#### Statement 2 — actual push/pull on one specific repo

| Field | Value | Why |
|---|---|---|
| Actions | `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `ecr:DescribeImages`, `ecr:DescribeRepositories`, `ecr:ListImages` | The minimum needed to push and inspect images. **No `ecr:DeleteRepository`, no `ecr:SetRepositoryPolicy`, no `ecr:PutLifecyclePolicy`**. |
| Resource | `arn:aws:ecr:us-east-1:649966627060:repository/devsecops-demo` | Scoped to ONE repository — cannot touch any other repo in the account. |

### Demonstration that the gate works

During Phase 7 verification, we ran `aws ecr describe-repositories` (no filter) from inside the Jenkins container:

```
User: arn:aws:sts::649966627060:assumed-role/devsecops-ec2-role/i-0c338f5f799c18f3a
      is not authorized to perform: ecr:DescribeRepositories on resource:
      arn:aws:ecr:us-east-1:649966627060:repository/*
```

The denial **proves** the policy scoping works: the role can interact only with the `devsecops-demo` repo. Listing all repos in the account is denied.

## 3. EC2 instance metadata hardening

In addition to scoping the IAM role, we hardened the EC2 metadata service:

| Setting | Value | Threat mitigated |
|---|---|---|
| `HttpTokens=required` (IMDSv2) | Session-token required | Defeats Server-Side Request Forgery (SSRF) attacks against the metadata service. This is the same class of vulnerability that led to the 2019 Capital One breach. |
| `HttpEndpoint=enabled` | Metadata service on | Required for the role-based auth chain to work |
| `HttpPutResponseHopLimit=2` | Containers can reach metadata via 1 hop | Without this, the Jenkins Docker container could not use the role |

## 4. What is deliberately NOT in the policy

| Action denied by default | Why we did not grant it |
|---|---|
| `ecr:DeleteRepository` | The pipeline never deletes the repo |
| `ecr:DeleteLifecyclePolicy` | Lifecycle policy is managed via IaC, not from CI |
| `ecr:SetRepositoryPolicy` | Repo policy is set once at create time |
| `ecr:PutRegistryScanningConfiguration` | Set once at repo create |
| `iam:*` | The pipeline never touches IAM |
| `ec2:*` | The pipeline does not manage EC2 |
| `s3:*` | The pipeline does not touch S3 |
| Any other service | Wildcard service-level access is denied by default |

## 5. Interview talking points

- "I followed the principle of least privilege: the build server has one specific IAM role, scoped to one specific ECR repo, with the smallest set of ECR actions that work."
- "There are no plain-text AWS access keys in Jenkins, the Jenkinsfile, the Docker image, or git history. The build uses the EC2 instance profile, which gets short-lived credentials from the metadata service."
- "I enforced IMDSv2 with required session tokens to defeat SSRF attacks on the metadata service. This is the Capital One breach lesson applied."
- "The deliberately-omitted actions are as important as the granted ones. The policy can't delete repos, can't modify repo policy, can't touch any other AWS service. A leak of this role would let the attacker push images to one ECR repo and nothing else."

## 6. Verification commands

```bash
# View the trust policy
aws iam get-role --role-name devsecops-ec2-role \
    --query 'Role.AssumeRolePolicyDocument'

# View the attached policies
aws iam list-attached-role-policies --role-name devsecops-ec2-role

# View the actual policy document
aws iam get-policy-version \
    --policy-arn arn:aws:iam::649966627060:policy/devsecops-ecr-push-policy \
    --version-id $(aws iam get-policy \
        --policy-arn arn:aws:iam::649966627060:policy/devsecops-ecr-push-policy \
        --query 'Policy.DefaultVersionId' --output text)

# Verify instance metadata config
aws ec2 describe-instances --instance-ids i-0c338f5f799c18f3a \
    --query 'Reservations[0].Instances[0].MetadataOptions'
```
