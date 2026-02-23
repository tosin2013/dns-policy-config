# ADR-003: DNS Operator Health Monitoring via RHACM Policy

## Status

Accepted

## Date

2026-02-23

## Context

The DNS Operator in OpenShift 4 manages the entire lifecycle of CoreDNS, running in the `openshift-dns-operator` namespace. Its health is tracked via the `ClusterOperator` resource named `dns`, which exposes conditions:

| Condition | Healthy State | Meaning |
|-----------|--------------|---------|
| Available | True | At least one CoreDNS pod is serving requests |
| Progressing | False | Configuration changes have been fully reconciled |
| Degraded | False | Operator and managed resources are functioning without errors |

**Observed state on hub cluster (2026-02-23):**
- `Available=True` — "DNS default is available"
- `Progressing=False` — "Desired and current number of DNSes are equal"
- `Degraded=False` — reason: `DNSNotDegraded`
- Operator version: 4.20.14

On `cluster1` (AWS us-east-1, OpenShift 4.21.2, 3 worker nodes), the same conditions must be continuously validated. If the DNS Operator enters a `Degraded` state, it signals that the fundamental name resolution service is failing.

## Decision

Author a `ConfigurationPolicy` that monitors the `ClusterOperator/dns` resource for healthy conditions (`Available=True`, `Degraded=False`) using `musthave` compliance type with `inform` remediation. Deploy this as the highest-priority DNS governance policy with `critical` severity.

### Policy Manifest

See [`policies/dns/operator-health-check.yaml`](../../policies/dns/operator-health-check.yaml) for the full manifest.

The policy uses `musthave` to verify that the ClusterOperator status contains the expected healthy conditions. If any condition deviates (e.g., `Degraded=True`), the policy reports `NonCompliant`.

## Rationale

- The ClusterOperator resource is the DNS Operator's own health-check surface — leveraging it avoids duplicating monitoring logic.
- `musthave` compliance allows partial matching: the policy only checks the conditions it cares about, ignoring unrelated status fields.
- Setting severity to `critical` ensures this violation stands out in PolicyReports and maps to `total_risk=4` in the `policyreport_info` metric.

## Consequences

### Positive

- Immediate detection of DNS Operator degradation across all managed clusters.
- Single policy covers the most impactful failure mode (global DNS instability).
- Works on any OpenShift 4.x cluster without version-specific logic.

### Negative

- Only detects operator-level failures — does not catch Corefile misconfigurations or resource exhaustion (addressed by ADR-004 and ADR-005).
- `musthave` on status conditions can produce transient violations during legitimate operator upgrades (mitigated by setting `for: 10m` in the associated AlertingRule — see ADR-006).

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
