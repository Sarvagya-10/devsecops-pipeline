# Security Policy

This is a learning / portfolio project. It is **not** a piece of software intended to be deployed by third parties to handle their workloads. That said, the project does ship live code and infrastructure-as-code, so security issues are taken seriously.

## Supported

Only the `main` branch is supported. There are no maintained release branches.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security problem. Instead:

- Email the maintainer at the address listed in the GitHub profile (`Sarvagya-10`).
- Include enough context for the issue to be reproduced — minimum: file, line numbers, attack scenario.
- Expect a first reply within 7 calendar days.

## Project-specific security posture

The project's own security posture is documented in:

- [`docs/security/iam-review.md`](docs/security/iam-review.md) — per-action IAM least-privilege justification.
- [`docs/architecture/architecture.md`](docs/architecture/architecture.md) — per-component design rationale, including PSS, NetworkPolicy, IMDSv2.

Security controls in the pipeline (every commit must pass these):

1. SonarQube SAST — Quality Gate must be Passed.
2. Trivy filesystem scan — 0 HIGH/CRITICAL vulns + 0 secrets + 0 IaC misconfigurations.
3. Trivy image scan — 0 HIGH/CRITICAL vulns in OS layer or installed packages.
4. AWS Inspector (ECR scan-on-push) — secondary cloud-native scan.

## What is NOT in scope

- Anti-cheat / anti-abuse — there is no production traffic to abuse.
- DDoS protection — the application has no public ingress in steady state.
- Multi-tenant isolation — single project, single AWS account, single namespace.
