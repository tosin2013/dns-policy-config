# ADR-005: CoreDNS Resource Exhaustion Detection

## Status

Accepted

## Date

2026-02-23

## Context

CoreDNS runs as a DaemonSet (`dns-default`) in the `openshift-dns` namespace, ensuring every node has a local resolver. Each pod runs two containers: the `dns` (CoreDNS) container and a `kube-rbac-proxy` sidecar for metrics.

**Observed state on hub cluster (2026-02-23, single-node):**
- DaemonSet `dns-default`: desiredNumberScheduled=1, numberAvailable=1, numberReady=1
- Pod `dns-default-9gvnj`: 2/2 Running
- Resource requests: cpu=50m, memory=70Mi (CoreDNS); cpu=10m, memory=40Mi (kube-rbac-proxy)

**cluster1 (AWS, 3 workers + 3 control-plane nodes):**
- Expected: 6 CoreDNS pods (one per node) based on DaemonSet scheduling with tolerations for master nodes.

CoreDNS pods can appear "Running" while being functionally degraded due to CPU throttling or memory pressure. If `numberAvailable < desiredNumberScheduled`, some nodes lack a local resolver, increasing latency and creating single points of failure.

## Decision

Author a `ConfigurationPolicy` that monitors the `dns-default` DaemonSet in `openshift-dns` and verifies that `status.numberAvailable` equals `status.desiredNumberScheduled`. Set remediation to `inform` with `high` severity.

### Policy Manifest

See [`policies/dns/resource-exhaustion.yaml`](../../policies/dns/resource-exhaustion.yaml) for the full manifest.

The policy uses `object-templates-raw` to look up the DaemonSet and compare available vs desired replica counts dynamically.

## Rationale

- The DaemonSet status fields are the authoritative source for CoreDNS pod availability per node.
- Comparing `numberAvailable` to `desiredNumberScheduled` catches both scheduling failures (node taints, resource pressure) and pod crashes.
- This complements ADR-003 (operator health): the operator may report healthy even when individual CoreDNS pods are missing, since `Available=True` only requires at least one pod running.

## Consequences

### Positive

- Detects "silent" failures where most CoreDNS pods are running but specific nodes lack resolvers.
- No false positives during normal DaemonSet rolling updates (the `maxUnavailable: 0` update strategy ensures pods are replaced one at a time with surge).
- Works dynamically — no need to hardcode node counts per cluster.

### Negative

- Transient violations may occur during node scale-up events (new node joins before DaemonSet pod is scheduled).
- Does not detect functional degradation within running pods (e.g., high latency due to resource limits) — that requires Prometheus metrics monitoring.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
