# ADR-011: DNS Endpoint Consistency Detection

## Status

Accepted

## Date

2026-03-25

## Context

During cluster upgrades, DNS configuration can drift — one cluster may end up with different upstream forwarders or a modified cluster DNS Service IP compared to others. This was observed in production when an upgrade changed the DNS setup on one cluster, causing resolution failures that were difficult to diagnose because the cluster otherwise appeared healthy.

Existing policies cover several aspects of DNS health:

| ADR | Coverage |
|-----|----------|
| ADR-003 | DNS Operator health (Available/Degraded conditions) |
| ADR-004 | Corefile plugin presence (forward, errors, health, cache) |
| ADR-005 | CoreDNS DaemonSet replica availability |

However, none of these validate that the actual DNS endpoint configuration — the DNS Operator custom resource and the cluster DNS Service IP — is consistent across clusters. A cluster can pass all three checks while having its DNS Operator configured with different upstream resolvers or a modified Service IP, leading to subtle resolution differences between clusters.

In OpenShift, pod DNS resolution flows through two layers:

1. **Cluster DNS Service** (`dns-default` in `openshift-dns`) — pods' resolv.conf points to this Service IP (default `172.30.0.10`)
2. **DNS Operator CR** (`dns.operator.openshift.io/default`) — controls CoreDNS behavior including upstream forwarder configuration via the `forward` directive in the Corefile

Drift at either layer can cause cross-cluster DNS inconsistency.

## Decision

Author a `ConfigurationPolicy` with two templates:

1. **dns-operator-upstream-config** — Verify the `DNS` operator CR (`operator.openshift.io/v1`, name `default`) exists in its expected state using `musthave` compliance. This baseline check detects when the operator CR is modified with unexpected upstream forwarders. Users who need to pin specific upstream servers (e.g., a corporate DNS) can extend the `musthave` objectDefinition with `spec.servers` or `spec.upstreamResolvers`.

2. **dns-cluster-service-ip** — Verify the `dns-default` Service in `openshift-dns` has `clusterIP: 172.30.0.10`. This is the OpenShift default and should not be changed. If the Service IP drifts, pods will fail to resolve DNS queries.

Both templates use `remediationAction: inform` with `severity: high`.

### Policy Manifest

See [`policies/dns/resolv-endpoint-consistency.yaml`](../../policies/dns/resolv-endpoint-consistency.yaml) for the full manifest.

### Why not check node /etc/resolv.conf directly?

RHACM ConfigurationPolicy can only inspect Kubernetes API objects, not host filesystem paths. Checking node-level resolv.conf would require a CronJob-based approach or integration with the Compliance Operator. However, in OpenShift, the node resolv.conf is inherited by CoreDNS as its upstream resolver (via the `forward . /etc/resolv.conf` directive). By validating the DNS Operator CR — which controls that `forward` directive — we effectively detect when upstream resolution behavior would differ across clusters.

## Rationale

- The DNS Operator CR is the authoritative source for upstream forwarder configuration. Changes to this CR propagate to the Corefile `forward` directive, which determines how non-cluster DNS queries are resolved.
- The cluster DNS Service IP is what every pod uses in its resolv.conf (`nameserver 172.30.0.10`). Drift in this value would break DNS for all workloads.
- Checking both layers provides defense-in-depth: the Operator CR catches upstream forwarder drift, while the Service IP check catches cluster DNS endpoint drift.
- This complements ADR-004 (Corefile integrity): ADR-004 checks that required plugins exist in the Corefile, while this policy checks that the Operator CR controlling the Corefile is in the expected state.

## Consequences

### Positive

- Catches upgrade-induced DNS drift before it causes outages across the fleet.
- Provides a clear signal when a cluster's DNS configuration diverges from the baseline, making troubleshooting faster.
- The `musthave` compliance type is extensible — teams can add specific upstream resolver IPs to the DNS Operator CR objectDefinition to enforce corporate DNS standards.

### Negative

- Does not cover node-level `/etc/resolv.conf` directly. Detecting node-level drift would require the Compliance Operator or a custom CronJob.
- The default `172.30.0.10` Service IP check may need adjustment for clusters using non-standard service CIDR ranges (though this is uncommon and explicitly discouraged).
- The baseline DNS Operator CR check (existence only) is intentionally minimal; organizations with specific upstream requirements should extend the objectDefinition.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
