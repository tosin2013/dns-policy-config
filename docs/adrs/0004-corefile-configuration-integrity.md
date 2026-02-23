# ADR-004: Corefile Configuration Integrity Validation

## Status

Accepted

## Date

2026-02-23

## Context

CoreDNS serves as the DNS resolution engine in OpenShift 4, with its configuration defined by a Corefile stored in `ConfigMap/dns-default` in the `openshift-dns` namespace. The Corefile uses a plugin-based architecture:

**Observed Corefile on hub cluster (2026-02-23):**

```
.:5353 {
    bufsize 1232
    errors
    log . { class error }
    health { lameduck 20s }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
    }
    prometheus 127.0.0.1:9153
    forward . /etc/resolv.conf { policy sequential }
    cache 900 { denial 9984 30 }
    reload
}
```

Critical plugins and their roles:

| Plugin | Purpose | Impact if Missing |
|--------|---------|-------------------|
| `errors` | Logs DNS errors for observability | Loss of error visibility |
| `health` | Exposes health endpoint for liveness probes | CoreDNS pods not restarted on failure |
| `forward` | Routes non-cluster queries to upstream resolvers | External DNS resolution fails |
| `cache` | Frontend cache reducing repeated lookups | Performance degradation, upstream overload |
| `kubernetes` | Service discovery for `.cluster.local` | Internal service resolution fails |

Configuration drift occurs when manual changes to the ConfigMap are overwritten by the DNS Operator, or when the operator's desired state diverges from organizational requirements (e.g., missing corporate forwarder).

## Decision

Author a `ConfigurationPolicy` using `object-templates-raw` to inspect the `dns-default` ConfigMap and verify that critical plugins are present in the Corefile. The policy checks for:

1. `forward` plugin with upstream resolver configuration
2. `errors` plugin for observability
3. `health` plugin for liveness probing
4. `cache` plugin for performance

Set remediation to `inform` with `high` severity.

### Policy Manifest

See [`policies/dns/corefile-integrity.yaml`](../../policies/dns/corefile-integrity.yaml) for the full manifest.

The policy uses `object-templates-raw` with hub template functions to dynamically look up the ConfigMap and evaluate its data content for required plugin strings.

## Rationale

- Standard `musthave` compliance cannot inspect string content within ConfigMap data fields — `object-templates-raw` enables substring matching against the Corefile text.
- Checking for plugin presence rather than exact Corefile content allows the policy to remain valid across OpenShift minor version upgrades that may adjust default parameters.
- Separating this from operator health (ADR-003) provides defense-in-depth: the operator can report healthy while the Corefile contains a misconfiguration.

## Consequences

### Positive

- Detects silent Corefile drift (e.g., removed `forward` directive) that would cause external resolution failures without triggering operator degradation.
- Flexible enough to add organization-specific checks (e.g., verify a corporate forwarder IP like `10.0.0.1`).
- Works across all managed clusters with the same base Corefile structure.

### Negative

- `object-templates-raw` policies are more complex to author and debug than standard `musthave` policies.
- String-based plugin detection may produce false positives if plugin names appear in comments or log directives.
- Requires updating if OpenShift fundamentally changes the Corefile structure in a future major version.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
