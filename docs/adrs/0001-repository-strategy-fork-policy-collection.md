# ADR-001: Repository Strategy — Fork policy-collection

## Status

Accepted

## Date

2026-02-23

## Context

Organizations managing DNS governance policies for OpenShift clusters via RHACM need a version-controlled repository to store and distribute policy manifests. Three options were evaluated:

1. **Fork `open-cluster-management-io/policy-collection`** — The upstream OCM community repository containing stable and community-contributed RHACM policies, including DNS configuration samples, ZTP node resolver policies, and infrastructure health validators.
2. **Fork `redhat-cop/acm-policies`** — A Red Hat Communities of Practice repository providing a Kustomize-based, GitOps-optimized project layout with bill-of-materials folders and regional overlays.
3. **Create a new repository from scratch** — Build a bespoke structure independent of community work.

Key evaluation criteria:

| Feature | policy-collection (OCM) | acm-policies (Red Hat COP) | New Repository |
|---------|------------------------|---------------------------|----------------|
| Philosophy | Upstream, manifest-centric, community-driven | Consultative, layout-centric, GitOps-optimized | Custom, no inherited structure |
| DNS Logic | Rich set of individual DNS policy examples | Structured framework for regional DNS overrides | Must be authored from zero |
| Complexity | Lower; easy to cherry-pick single files | Higher; requires Kustomize and BOM knowledge | Variable |
| Upstream Sync | Direct alignment with RHACM docs | Separate maintenance cadence | No upstream |

## Decision

Fork `open-cluster-management-io/policy-collection` as the base repository for DNS governance policies.

## Rationale

- Provides immediate access to a library of pre-tested policy manifests, including DNS-specific examples in the `stable/CM-Configuration-Management` category.
- Aligns with the OCM project's folder structure, which is the standard layout recognized by RHACM hub subscription controllers.
- Enables pulling upstream updates (new vulnerability patterns, RBAC policies, certificate checks) with minimal merge effort.
- Allows contributing custom DNS monitoring logic back to the community via pull requests.
- Lower barrier to entry compared to the Kustomize-heavy `acm-policies` layout.

## Alternatives Rejected

- **`redhat-cop/acm-policies`**: Superior for complex multi-region deployments with Kustomize overlays, but introduces unnecessary complexity for an initial DNS governance rollout. Can be adopted later if regional overrides demand it.
- **New repository**: Would duplicate much of the OCM structure (RHACM policies must follow specific CRD patterns regardless), leading to maintenance debt and isolation from community improvements.

## Consequences

### Positive

- Inherited library of stable, tested policies accelerates initial deployment.
- Community alignment ensures compatibility with future RHACM versions.
- Weekly upstream sync pipeline keeps security-related policies current.

### Negative

- Fork maintenance requires periodic merge resolution when upstream changes conflict with custom DNS policies.
- The flat manifest structure may need Kustomize overlays added later for multi-region deployments (see ADR-007).

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
