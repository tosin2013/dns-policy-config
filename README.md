# DNS Policy Configuration for OpenShift / RHACM

Strategic architectural governance for DNS infrastructure within Red Hat OpenShift and Advanced Cluster Management (RHACM). This repository contains Architecture Decision Records (ADRs) and executable RHACM policies for automated DNS misconfiguration alerting across multicluster environments.

## Repository Structure

```
docs/adrs/          # Architecture Decision Records (ADR-001 through ADR-010)
policies/dns/       # RHACM ConfigurationPolicy manifests for DNS governance
policies/observability/  # AlertingRule and observability integration manifests
demo/               # Deployment manifests for applying policies to managed clusters
```

## ADR Index

| ID | Decision | Status |
|----|----------|--------|
| [ADR-001](docs/adrs/0001-repository-strategy-fork-policy-collection.md) | Repository Strategy: Fork policy-collection | Accepted |
| [ADR-002](docs/adrs/0002-policy-remediation-mode-inform-first.md) | Policy Remediation Mode: Inform-First for DNS | Accepted |
| [ADR-003](docs/adrs/0003-dns-operator-health-monitoring.md) | DNS Operator Health Monitoring | Accepted |
| [ADR-004](docs/adrs/0004-corefile-configuration-integrity.md) | Corefile Configuration Integrity Validation | Accepted |
| [ADR-005](docs/adrs/0005-coredns-resource-exhaustion-detection.md) | CoreDNS Resource Exhaustion Detection | Accepted |
| [ADR-006](docs/adrs/0006-observability-alerting-integration.md) | Observability and Alerting Stack Integration | Accepted |
| [ADR-007](docs/adrs/0007-regional-dns-location-aware-policies.md) | Regional DNS with Location-Aware Policies | Accepted |
| [ADR-008](docs/adrs/0008-dnssec-validation-monitoring.md) | DNSSEC Validation Monitoring | Accepted |
| [ADR-009](docs/adrs/0009-gitops-policy-lifecycle-argocd.md) | GitOps Policy Lifecycle via ArgoCD | Accepted |
| [ADR-010](docs/adrs/0010-placement-api-adoption.md) | Placement API Adoption over PlacementRule | Accepted |

## Policies

| Policy | Target Resource | Remediation | ADR |
|--------|----------------|-------------|-----|
| [operator-health-check](policies/dns/operator-health-check.yaml) | ClusterOperator/dns | inform | ADR-003 |
| [corefile-integrity](policies/dns/corefile-integrity.yaml) | ConfigMap/dns-default | inform | ADR-004 |
| [resource-exhaustion](policies/dns/resource-exhaustion.yaml) | DaemonSet/dns-default | inform | ADR-005 |
| [dns-alerting-rule](policies/observability/dns-alerting-rule.yaml) | AlertingRule | enforce | ADR-006 |

## Demo: Applying Policies to a Managed Cluster

The `demo/` directory contains manifests to deploy these policies against an RHACM-managed cluster:

```bash
# Apply all policies and target cluster1
./demo/apply.sh
```

See the demo [apply script](demo/apply.sh) for step-by-step instructions.

### RHACM Governance Dashboard

All 4 DNS governance policies deployed and reporting compliance against `cluster1`:

![RHACM Governance Dashboard](docs/rhacm-governance-dashboard.png)

## Prerequisites

- Red Hat OpenShift Container Platform 4.x hub cluster
- Red Hat Advanced Cluster Management for Kubernetes (RHACM) 2.4+
- At least one managed cluster (e.g., `cluster1`)
- `oc` CLI authenticated to the hub cluster
