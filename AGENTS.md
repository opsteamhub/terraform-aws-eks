# Repository instructions

This repository contains a reusable Terraform module for Amazon EKS. Treat `variables.tf` as the input contract, `output.tf` as the output contract, and `docs/` as the architecture and migration record.

## Working rules

- Keep the module provider- and backend-agnostic. Provider configuration, credentials, Region, state, and locking belong to the calling root module.
- Never run `terraform apply` against a real AWS account while developing this module. Automated tests use mocked AWS and TLS providers and require no credentials.
- Do not commit state, plans, provider binaries, credentials, customer identifiers, kubeconfigs, tokens, or backend configuration.
- Require explicit subnet IDs. Do not add tag-based VPC or subnet discovery to make an example shorter.
- Preserve existing resource addresses unless a breaking change is intentional and documented in `docs/MIGRATION-v2.md`.
- Keep cluster names stable and caller-defined. Flag plans that replace a control plane, KMS key, IAM role, launch template, or node group.
- Preserve private-only API, KMS encryption, full control-plane logging, AL2023, encrypted storage, IMDSv2, and required organizational tags as defaults.
- Add input validation plus positive and negative tests when changing a contract.
- Keep examples safe: no remote backend, no secrets, no customer IDs, and no unrestricted public endpoint.
- Use Conventional Commits in English. Do not create a tag or release from a feature branch.

## Required checks

Run from the repository root before proposing a change:

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test -test-directory=testing

terraform -chdir=examples/basic init -backend=false -input=false
terraform -chdir=examples/basic validate
terraform -chdir=examples/complete init -backend=false -input=false
terraform -chdir=examples/complete validate
terraform -chdir=examples/bottlerocket init -backend=false -input=false
terraform -chdir=examples/bottlerocket validate
terraform -chdir=examples/capabilities init -backend=false -input=false
terraform -chdir=examples/capabilities validate
terraform -chdir=examples/auto-mode init -backend=false -input=false
terraform -chdir=examples/auto-mode validate

tflint --init
tflint --recursive --format compact
trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

Validate the repository agent configuration against its pinned schema:

```bash
check-jsonschema \
  --schemafile "$(jq -r '.\"$schema\"' .kiro/agents/local-agent.json)" \
  .kiro/agents/local-agent.json
```

Terraform provider mocking requires Terraform 1.7 or newer. CI is the source of truth for exact tool versions.

## Review focus

EKS changes can remove operator access, replace a control plane, disrupt nodes, expose the Kubernetes API, or broaden IAM trust. Review name, version, service CIDR, subnet, endpoint, access mode, KMS, IAM, add-on, capability, Auto Mode, launch-template, AMI, and scaling changes explicitly. For Auto Mode, verify all three capabilities change together, self-managed add-on bootstrap remains disabled, access entries remain enabled, the immutable node role is intentional, and standard add-ons remain during hybrid migration. For ACK, review both the capability role and who can create its Kubernetes custom resources. For Argo CD, review Identity Center mappings, target-cluster RBAC, repository credentials, and network access. Capability deletion retains managed Kubernetes resources and CRDs, so remove those resources deliberately before deletion. Mocked tests do not verify AWS quotas, organization policies, network reachability, AMI compatibility, add-on or capability readiness, Auto Mode workload migration, Kubernetes NodePool/NodeClass behavior, workload disruption, or Kubernetes RBAC; require a controlled sandbox plan/apply before a major release.
