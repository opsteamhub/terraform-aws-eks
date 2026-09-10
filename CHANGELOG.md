# Changelog

All notable changes to this project will be documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses semantic versioning after the first versioned release.

## [1.0.1](https://github.com/opsteamhub/terraform-aws-eks/compare/v1.0.0...v1.0.1) (2026-09-10)


### Bug Fixes

* **ci:** remove duplicate Dependabot ecosystem ([cead556](https://github.com/opsteamhub/terraform-aws-eks/commit/cead556df2ee32189b6fd4b2de8d52e9d28bbf4a))
* **eks:** propagate tags to managed node network interfaces ([23e3476](https://github.com/opsteamhub/terraform-aws-eks/commit/23e34763a548e1af458e0d39ed7d53d6e31540a8))

## [Unreleased]

### Added

- Self-contained KMS keys and EC2 launch templates with no unpinned Git module dependencies.
- EKS Access API entries, scoped access policies, IRSA, external OIDC identity providers, and Pod Identity associations.
- Working EKS add-on management with compatible-version defaults.
- Opt-in EKS Auto Mode for pure or hybrid clusters, with coordinated compute/network/storage configuration, built-in node-pool controls, AWS-recommended managed IAM, external-role support, outputs, tests, example, and migration guidance.
- EKS-managed ACK, Argo CD, and KRO Capabilities with dedicated IAM roles, external-role support, typed Argo CD configuration, and least-privilege guardrails.
- A validated Bottlerocket managed-node example with TOML user data.
- Required organizational tags, input validation, structured outputs, mocked tests, examples, CI, security policy, migration guidance, and repository agent configuration.

### Changed

- Require Terraform 1.7+ and AWS provider 6.25+.
- Use stable caller-defined cluster names and explicit subnet IDs.
- Default to EKS 1.35, AL2023, private-only API access, all control-plane logs, customer-managed secret encryption, IMDSv2, encrypted gp3 storage, and automatic node repair.
- Resolve baseline add-ons by compute model: standard and hybrid clusters keep CoreDNS, kube-proxy, and VPC CNI, while pure Auto Mode uses AWS-managed core components.
- Replace the v1 input contract and resource-address graph. See `docs/MIGRATION-v2.md`.

### Removed

- Random cluster names and service CIDRs.
- Hidden VPC/subnet discovery, deprecated null data sources, stale AL2 bootstrap templates, version-gated IRSA, dead add-on code, and debug outputs.
- SSH-based, unpinned KMS and launch-template module dependencies.
