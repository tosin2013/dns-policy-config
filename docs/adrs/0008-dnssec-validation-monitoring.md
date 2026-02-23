# ADR-008: DNSSEC Validation Monitoring

## Status

Accepted

## Date

2026-02-23

## Context

DNS Security Extensions (DNSSEC) protect against DNS spoofing and cache poisoning by enabling cryptographic verification of DNS responses. When DNSSEC validation is enabled in CoreDNS, the cluster verifies signatures on DNS responses from upstream resolvers.

Critical DNSSEC failure modes:
- **Expired signatures**: Upstream zone maintainer fails to re-sign records, causing validation failures that look like resolution outages.
- **Missing trust anchors**: The CoreDNS trust anchor configuration is incomplete, rejecting valid signed responses.
- **Silent denials**: Queries fail DNSSEC validation and are silently dropped without useful error messages unless `log-failures` is enabled.

**Observed state on hub cluster (2026-02-23):**
The default Corefile does not include a `dnssec` plugin — OpenShift 4 does not enable DNSSEC validation by default. However, organizations with strict security requirements may enable it via custom DNS Operator configuration.

## Decision

Author an RHACM policy that monitors for DNSSEC-related configuration when organizations enable it. The policy has two modes:

1. **Baseline mode**: Verify that if `dnssec` appears in the Corefile, `log-failures` is also enabled to ensure visibility into validation errors.
2. **Enforcement mode** (optional, not default): Verify that `dnssec` is present in the Corefile for organizations that mandate it.

Set remediation to `inform` with `medium` severity, as DNSSEC misconfiguration affects security posture rather than immediate availability.

## Rationale

- DNSSEC validation failures produce "silent" resolution failures that are extremely difficult to diagnose without error logging.
- A policy that checks for `log-failures` alongside `dnssec` ensures that if validation is enabled, its failure modes are observable.
- Making DNSSEC presence optional (baseline mode) avoids false violations on clusters that intentionally do not use DNSSEC.

## Alternatives Rejected

- **Mandatory DNSSEC enforcement for all clusters**: Not all upstream resolvers or zones support DNSSEC. Forcing validation would break resolution for unsigned zones.
- **Ignoring DNSSEC entirely**: Organizations in regulated industries (finance, government) may require DNSSEC. Having no policy means no visibility into misconfiguration.

## Consequences

### Positive

- Catches the most dangerous DNSSEC failure mode: enabled validation without error logging, which leads to silent query failures.
- Does not require DNSSEC on clusters where it is not needed — respects operational flexibility.
- Provides a foundation for organizations to adopt DNSSEC incrementally.

### Negative

- Limited value on clusters that do not use DNSSEC (policy evaluates to compliant by default).
- DNSSEC-specific troubleshooting still requires domain expertise beyond what the policy can surface.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**, **SC-System and Communications Protection**
