# ADR-007: Regional DNS with Location-Aware Policies

## Status

Accepted

## Date

2026-02-23

## Context

In multicluster environments, DNS requirements vary by region. Different data centers may have distinct upstream resolvers, corporate forwarders for regional storage controllers (e.g., vSphere CSI datastores), or compliance requirements for DNS traffic routing.

**Observed cluster claims on cluster1:**
- `region.open-cluster-management.io` = `us-east-1`
- `platform.open-cluster-management.io` = `AWS`
- `infrastructure.openshift.io` = `{"infraName":"cluster1-5wc9w"}`

RHACM policies support hub-side templating via `lookup` and `fromClusterClaim` functions, enabling a single policy definition to adapt its expected state based on the managed cluster's location metadata.

Without location-awareness, organizations face two undesirable options:
1. A single generic policy that ignores regional DNS differences — producing false violations.
2. Dozens of nearly identical per-region policies — creating maintenance burden and hub CPU overhead.

## Decision

Use RHACM hub template functions (`fromClusterClaim`, `lookup`) within `object-templates-raw` to create location-aware DNS policies. A single policy definition dynamically adjusts the expected Corefile forwarder configuration based on the `region.open-cluster-management.io` cluster claim.

### Example Pattern

```yaml
{{- $region := (fromClusterClaim "region.open-cluster-management.io") }}
{{- if eq $region "us-east-1" }}
  # Expect forwarder pointing to us-east-1 corporate DNS
{{- else if eq $region "eu-west-1" }}
  # Expect forwarder pointing to eu-west-1 corporate DNS
{{- else }}
  # Default: expect SystemResolvConf
{{- end }}
```

This pattern is used when organizational DNS policy requires region-specific upstream resolvers.

## Rationale

- A single policy template replaces N per-region policies, reducing hub controller CPU load and simplifying maintenance.
- Cluster claims are automatically populated by RHACM from the managed cluster's infrastructure — no manual labeling required for standard fields.
- The same mechanism can be extended to other location-dependent configurations beyond DNS (NTP servers, proxy settings, registry mirrors).

## Alternatives Rejected

- **Per-region policy copies**: Each region gets its own policy YAML with hardcoded forwarder IPs. Simple but creates O(N) maintenance burden and risks configuration drift between copies.
- **Kustomize overlays only**: Generates per-region manifests at build time via `redhat-cop/acm-policies` layout. Effective but loses runtime adaptability — new regions require a pipeline rebuild.

## Consequences

### Positive

- Single policy definition scales to any number of regions without additional manifests.
- Leverages existing RHACM cluster claim infrastructure — no custom operators or CRDs needed.
- Naturally self-documenting: the template logic explicitly maps regions to DNS expectations.

### Negative

- Hub template rendering adds a small amount of processing latency during policy evaluation.
- Complex template logic can be difficult to debug when violations occur — the rendered policy on the managed cluster must be inspected to understand what was evaluated.
- Requires cluster claims to be accurately populated — miscategorized clusters will receive incorrect DNS expectations.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
