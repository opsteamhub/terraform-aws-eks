## Summary

<!-- Explain the behavior and why it is needed. -->

## Compatibility and state impact

<!-- List input/output changes, resource-address moves, replacements, and migration steps. -->

## Security, access, and cost

<!-- Cover endpoint exposure, IAM/KMS changes, operator access, workload identity, logs, and AWS charges. -->

## Verification

- [ ] `terraform fmt -check -recursive`
- [ ] `terraform validate`
- [ ] `terraform test -test-directory=testing`
- [ ] Basic and complete examples validate
- [ ] TFLint passes
- [ ] Trivy has no HIGH/CRITICAL failures
- [ ] Agent configuration schema validates
- [ ] Sandbox plan/apply completed when required

## Rollback

<!-- Explain source/config/state rollback and any non-reversible AWS changes. -->
