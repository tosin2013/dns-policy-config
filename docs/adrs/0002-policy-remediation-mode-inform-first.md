# ADR-002: Policy Remediation Mode — Inform-First for DNS

## Status

Accepted

## Date

2026-02-23

## Context

RHACM policies support two remediation actions:

| Mode | Behavior | Risk |
|------|----------|------|
| `inform` | Monitors cluster state and reports violations without making changes | None — read-only audit |
| `enforce` | Actively reconciles actual state to match the desired state | May disrupt running services if the desired state is incorrect |

DNS is a foundational service — every pod depends on it for service discovery and external resolution. On the observed hub cluster, the DNS Operator (v4.20.14) is healthy with `Available=True`, `Degraded=False`. The Corefile uses standard upstream resolution via `/etc/resolv.conf` with a 900-second cache. Any unintended modification to this configuration could cause cluster-wide resolution failures.

## Decision

Use `inform` as the default `remediationAction` for all DNS monitoring policies during initial rollout. The `enforce` mode is reserved only for policies that create new resources (e.g., AlertingRule in ADR-006) rather than modifying existing DNS infrastructure.

## Rationale

- DNS misconfiguration enforcement could overwrite intentional customizations (e.g., customer-specific forwarders) without operator awareness.
- `inform` mode surfaces architectural drift for manual review, allowing infrastructure teams to assess the root cause before remediation.
- Policy violations in `inform` mode are captured in `PolicyReport` CRs and the `policyreport_info` Prometheus metric, providing full observability without operational risk.
- Organizations can selectively promote individual policies to `enforce` after validating them in `inform` mode across all managed clusters.

## Alternatives Rejected

- **`enforce` for all policies**: Unacceptable risk for DNS infrastructure. A policy misconfiguration could cascade into cluster-wide name resolution failure. Self-healing is desirable but premature without a proven policy baseline.
- **Mixed mode without clear criteria**: Leads to operational confusion about which policies auto-remediate and which require manual intervention.

## Consequences

### Positive

- Zero risk of policy-induced DNS outages during initial rollout.
- Violations are visible in RHACM console, PolicyReports, and Prometheus metrics.
- Provides a safe "dry run" period to validate policy logic against real cluster state.

### Negative

- Misconfigurations are detected but not automatically corrected — requires human intervention.
- Mean Time to Resolution (MTTR) is higher than with `enforce` mode until policies are promoted.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
