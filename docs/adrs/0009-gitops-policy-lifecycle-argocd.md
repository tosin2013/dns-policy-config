# ADR-009: GitOps Policy Lifecycle via ArgoCD

## Status

Accepted

## Date

2026-02-23

## Context

RHACM policies exist as Kubernetes custom resources on the hub cluster. Without a GitOps synchronization mechanism, policy changes require direct `oc apply` or RHACM console edits — creating audit gaps and configuration drift between the source repository and the live cluster state.

OpenShift GitOps (ArgoCD) provides declarative, Git-driven synchronization of Kubernetes resources. By pointing an ArgoCD `Application` at the policy repository, every commit becomes an auditable deployment event.

**Integration points:**
- The policy repository (forked from `policy-collection` per ADR-001) serves as the Git source of truth.
- ArgoCD syncs policy manifests to the hub cluster namespace (`dns-governance-policies`).
- RHACM's own controllers handle propagation from the hub to managed clusters.

```
Git Repository -> ArgoCD -> Hub Cluster -> RHACM spec-sync -> Managed Clusters
```

## Decision

Use OpenShift GitOps (ArgoCD) as the synchronization mechanism for deploying DNS governance policies from the Git repository to the RHACM Hub cluster. ArgoCD manages the Policy, Placement, and PlacementBinding resources; RHACM handles distribution to managed clusters.

### Synchronization Boundary

ArgoCD is responsible for:
- Policy CRDs, Placement, PlacementBinding in the `dns-governance-policies` namespace
- ManagedClusterSetBinding for namespace-to-ClusterSet access

ArgoCD does NOT manage:
- ManagedCluster resources (owned by RHACM)
- Policy propagation to managed clusters (owned by RHACM spec-sync controller)

## Rationale

- Every policy change is traceable to a Git commit, providing a full audit trail for compliance requirements.
- Pull request workflows enable peer review of policy changes before they reach production clusters.
- ArgoCD drift detection alerts when live policy state diverges from Git (e.g., manual console edits).
- Automated sync ensures new clusters added to the fleet are immediately onboarded into the DNS monitoring framework.

## Alternatives Rejected

- **RHACM Subscription/Channel (GitOps v1)**: The older RHACM pattern for Git-driven policy delivery. Still functional but being superseded by ArgoCD integration in RHACM 2.7+. More complex to configure and lacks ArgoCD's drift detection and UI.
- **Manual `oc apply`**: Acceptable for development but creates audit gaps and is not scalable for multi-environment deployments.
- **Helm-based deployment**: Adds unnecessary templating complexity when policies are already Kubernetes-native YAML. Kustomize overlays (if needed per ADR-007) are simpler.

## Consequences

### Positive

- Full audit trail: every policy deployment maps to a Git commit SHA.
- Peer review via pull requests catches policy errors before deployment.
- Drift detection prevents "shadow" policy changes via direct cluster access.
- Automatic onboarding of new managed clusters via existing Placement rules.

### Negative

- Adds ArgoCD as an operational dependency — ArgoCD outage delays policy updates (does not affect already-deployed policies).
- Requires careful RBAC configuration to ensure ArgoCD's service account can manage RHACM policy CRDs.
- Two control planes (ArgoCD + RHACM) managing overlapping resources requires clear ownership boundaries.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**, **AU-Audit and Accountability**
