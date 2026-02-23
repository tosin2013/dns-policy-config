# ADR-010: Placement API Adoption over PlacementRule

## Status

Accepted

## Date

2026-02-23

## Context

RHACM provides two mechanisms for selecting which managed clusters receive a policy:

1. **PlacementRule** (`apps.open-cluster-management.io/v1`): The legacy cluster selection API. Supports label selectors and cluster conditions but has limited scheduling capabilities.
2. **Placement** (`cluster.open-cluster-management.io/v1beta1`): The modern cluster selection API within the Open Cluster Management project. Provides enhanced scheduling with tolerations, spread policies, prioritizers, and ManagedClusterSet-scoped selection.

**Observed on the hub cluster (RHACM 2.15.1):**
- Both APIs are available.
- `cluster1` belongs to ManagedClusterSet `default` with labels `name=cluster1`, `region=us-east-1`, `cloud=Amazon`.
- PlacementRule is deprecated in RHACM 2.10+ and will be removed in a future release.

## Decision

Use the `Placement` API (`cluster.open-cluster-management.io/v1beta1`) exclusively for all DNS governance policies. Do not use the legacy `PlacementRule` API.

### Placement Pattern for cluster1

```yaml
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: dns-policy-placement
  namespace: dns-governance-policies
spec:
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchExpressions:
            - key: name
              operator: In
              values:
                - cluster1
```

Combined with a `ManagedClusterSetBinding` that grants the policy namespace access to the `default` ClusterSet.

## Rationale

- `PlacementRule` is deprecated in RHACM 2.10+ — investing in it creates technical debt.
- `Placement` integrates with `ManagedClusterSet`, providing namespace-scoped cluster selection that enforces multi-tenancy boundaries.
- `Placement` supports advanced scheduling features (tolerations, spread constraints, prioritizers) that will be needed as the fleet grows beyond a single cluster.
- The `Placement` API is the standard within the Open Cluster Management project, ensuring alignment with upstream community direction.

## Alternatives Rejected

- **PlacementRule**: Still functional on RHACM 2.15.1 but deprecated. Using it would require migration effort when it is eventually removed.
- **Direct namespace-based targeting**: Copying policies directly into managed cluster namespaces on the hub bypasses the placement framework entirely. Functional but loses the declarative selection model and breaks the governance audit trail.

## Consequences

### Positive

- Future-proof: aligned with the OCM community roadmap and RHACM deprecation timeline.
- ManagedClusterSet scoping provides built-in multi-tenancy — prevents policies from accidentally targeting clusters they should not.
- A single Placement can be extended with `matchExpressions` for region, cloud provider, or version-based targeting without creating additional resources.

### Negative

- Requires a `ManagedClusterSetBinding` in the policy namespace — an extra resource that PlacementRule did not need.
- Teams familiar with PlacementRule syntax must learn the Placement API (different field names, different `apiVersion`).
- Some older RHACM documentation and community examples still reference PlacementRule, requiring translation.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
