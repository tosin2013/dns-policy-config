# ADR-012: Upstream DNS Forwarder Validation

## Status

Accepted

## Date

2026-03-25

## Context

Organizations running multiple OpenShift clusters often configure custom upstream DNS forwarders via the DNS Operator CR (`operator.openshift.io/v1`, name `default`). The `spec.upstreamResolvers` field controls where CoreDNS forwards non-cluster DNS queries — for example, a corporate DNS server at `192.168.1.10` instead of the node's default `/etc/resolv.conf`.

During cluster upgrades, this configuration can drift: an upgrade may reset or modify the DNS Operator CR, causing one cluster to forward queries to a different upstream than the rest of the fleet. This leads to subtle resolution differences that are difficult to diagnose because the cluster otherwise appears healthy.

Existing policies cover related but distinct concerns:

| ADR | Coverage | Gap |
|-----|----------|-----|
| ADR-004 | Corefile plugin presence (forward, errors, health, cache) | Checks that `forward` exists, but not where it points |
| ADR-011 | DNS Operator CR existence + cluster DNS Service IP | Checks the CR exists, but not its `spec.upstreamResolvers` content |

Neither validates the **actual upstream DNS targets** configured on the DNS Operator CR.

### Red Hat Documentation

- [DNS Operator in OpenShift — Configuring upstream resolvers](https://docs.redhat.com/en/documentation/openshift_dedicated/4/html/networking_operators/dns-operator): Covers `spec.upstreamResolvers`, `spec.servers`, upstream types (`SystemResolvConf`, `Network`), and the `policy` field for upstream selection order.
- [DNS Operator API reference (operator.openshift.io/v1)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/operator_apis/dns-operator-openshift-io-v1): Full API specification for the DNS CR fields.

The `spec.upstreamResolvers` object supports two upstream types:

- `SystemResolvConf` — forwards to the node's `/etc/resolv.conf` (the default if `spec.upstreamResolvers` is not set)
- `Network` — forwards to a specific IP and port (e.g., `address: 192.168.1.10`, `port: 53`)

## Decision

Author an **optional** `ConfigurationPolicy` (disabled by default) that validates the DNS Operator CR's `spec.upstreamResolvers` field matches an expected baseline.

The policy ships with an example upstream configuration:

```yaml
spec:
  upstreamResolvers:
    upstreams:
      - type: Network
        address: 192.168.1.10
        port: 53
```

Users must customize the upstream IP to match their environment before enabling the policy (set `disabled: false`).

Set remediation to `inform` with `severity: high`.

### Why disabled by default?

Unlike the other DNS governance policies which apply universally to all OpenShift clusters, upstream forwarder configuration varies per organization. Shipping the policy enabled with a placeholder IP would cause false positives across every cluster. Users enable it only after filling in their actual upstream DNS server addresses.

### Policy Manifest

See [`policies/dns/upstream-forwarder-validation.yaml`](../../policies/dns/upstream-forwarder-validation.yaml) for the full manifest with inline comments explaining how to customize and enable.

## Rationale

- The DNS Operator CR's `spec.upstreamResolvers` is the authoritative source for upstream forwarder configuration. Changes to this field propagate to the Corefile's `forward` directive, altering where all non-cluster DNS queries are sent.
- `musthave` compliance ensures the expected upstream config is present on the CR. If an upgrade removes or modifies the upstream entry, the policy reports NonCompliant.
- Making this optional (disabled by default) avoids false positives while still providing a ready-to-use template that organizations can adopt with minimal effort.
- This complements ADR-004 (Corefile integrity) and ADR-011 (endpoint consistency): ADR-004 checks that the `forward` plugin exists, ADR-011 checks the CR exists and the Service IP is correct, and this policy checks what the `forward` plugin actually points to.

## Consequences

### Positive

- Catches upstream forwarder drift during upgrades before it causes cross-cluster DNS inconsistency.
- Provides a documented, ready-to-customize template with Red Hat documentation references — reduces the barrier for organizations to enforce upstream DNS standards.
- The inline YAML comments explain exactly what to change and how, making the policy self-documenting.

### Negative

- Requires per-organization customization before use — cannot be deployed universally out of the box.
- `musthave` only verifies that the expected entries exist; it cannot detect unexpected *additional* upstreams added to the CR (e.g., a rogue forwarder). A `mustonlyhave` compliance type would be needed for strict matching, but is not supported.
- Organizations using the default `SystemResolvConf` upstream (no custom forwarders) do not need this policy — the existing ADR-011 endpoint consistency check is sufficient for them.

## Compliance Mapping

RHACM Governance Taxonomy: **CM-Configuration-Management**
