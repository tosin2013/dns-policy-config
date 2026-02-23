# ADR-006: Observability and Alerting Stack Integration

## Status

Accepted

## Date

2026-02-23

## Context

RHACM policy violations in `inform` mode produce signals that must be transformed into actionable alerts for incident response teams. The governance framework provides two integration points:

1. **PolicyReport CRs** — Created on managed clusters, aggregating governance findings. The `policyreport_info` metric is exposed by the insights client and scrapeable by Prometheus.
2. **RHACM Console** — Displays compliance status per policy per cluster, but requires manual monitoring.

For DNS policies with `critical` severity (ADR-003), the violation must reach on-call engineers within minutes, not hours. This requires integration with the OpenShift monitoring stack (Prometheus + AlertManager) via `AlertingRule` CRs.

**Observed on hub cluster:** OpenShift monitoring stack is active in `openshift-monitoring`. cluster1 has the `governance-policy-framework` addon available.

## Decision

Deploy an `AlertingRule` CR on managed clusters (via an `enforce`-mode policy) that fires when the `policyreport_info` metric indicates a DNS policy failure. The AlertingRule integrates with the existing AlertManager configuration for notification routing (email, Slack, PagerDuty).

### AlertingRule

See [`policies/observability/dns-alerting-rule.yaml`](../../policies/observability/dns-alerting-rule.yaml) for the full manifest.

The `enforce` remediation is used specifically for this policy because it creates a new resource (AlertingRule) rather than modifying existing DNS infrastructure, making it safe for automated deployment.

## Rationale

- Bridges the gap between "policy violation detected" and "engineer notified" without requiring custom monitoring infrastructure.
- Uses the standard OpenShift `AlertingRule` API (`monitoring.openshift.io/v1`), ensuring compatibility with any AlertManager configuration.
- The `for: 10m` duration prevents alerting on transient violations during legitimate operator upgrades or node scaling events.
- Setting severity to `critical` in the AlertingRule aligns with the policy severity, ensuring consistent priority handling.

## Consequences

### Positive

- DNS policy violations trigger alerts through the same pipeline as infrastructure alerts (Prometheus -> AlertManager -> notification channel).
- Zero additional monitoring infrastructure required — reuses the existing OpenShift monitoring stack.
- The AlertingRule is version-controlled and deployed as code alongside the policies.

### Negative

- Requires `enforce` remediation for the AlertingRule policy, breaking the "inform-only" principle from ADR-002 (justified exception since it creates, not modifies).
- AlertManager routing configuration (receivers, routes) must be pre-configured on managed clusters for notifications to reach the correct team.
- The `policyreport_info` metric availability depends on the insights client running on managed clusters.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
