# Changelog

All notable changes to this project will be documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses semantic versioning after the first versioned release.

## [Unreleased]

### Added

- Self-contained KMS keys and EC2 launch templates with no unpinned Git module dependencies.
- EKS Access API entries, scoped access policies, IRSA, external OIDC identity providers, and Pod Identity associations.
- Working EKS add-on management with compatible-version defaults.
- EKS-managed ACK, Argo CD, and KRO Capabilities with dedicated IAM roles, external-role support, typed Argo CD configuration, and least-privilege guardrails.
- A validated Bottlerocket managed-node example with TOML user data.
- Required organizational tags, input validation, structured outputs, mocked tests, examples, CI, security policy, migration guidance, and repository agent configuration.

### Changed

- Require Terraform 1.7+ and AWS provider 6.25+.
- Use stable caller-defined cluster names and explicit subnet IDs.
- Default to EKS 1.35, AL2023, private-only API access, all control-plane logs, customer-managed secret encryption, IMDSv2, encrypted gp3 storage, and automatic node repair.
- Replace the v1 input contract and resource-address graph. See `docs/MIGRATION-v2.md`.

### Removed

- Random cluster names and service CIDRs.
- Hidden VPC/subnet discovery, deprecated null data sources, stale AL2 bootstrap templates, version-gated IRSA, dead add-on code, and debug outputs.
- SSH-based, unpinned KMS and launch-template module dependencies.
