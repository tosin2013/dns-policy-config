#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NS="dns-governance-policies"

echo "=== DNS Governance Policy Demo ==="
echo "Target: cluster1 via RHACM hub"
echo ""

echo "[1/5] Creating namespace: $NS"
oc apply -f "$SCRIPT_DIR/namespace.yaml"

echo "[2/5] Binding ManagedClusterSet 'default' to namespace"
oc apply -f "$SCRIPT_DIR/clusterset-binding.yaml"

echo "[3/5] Applying DNS governance policies"
oc apply -f "$REPO_ROOT/policies/dns/operator-health-check.yaml"
oc apply -f "$REPO_ROOT/policies/dns/corefile-integrity.yaml"
oc apply -f "$REPO_ROOT/policies/dns/resource-exhaustion.yaml"
oc apply -f "$REPO_ROOT/policies/observability/dns-alerting-rule.yaml"

echo "[4/5] Creating Placement and PlacementBinding targeting cluster1"
oc apply -f "$SCRIPT_DIR/placement.yaml"
oc apply -f "$SCRIPT_DIR/placement-binding.yaml"

echo "[5/5] Waiting for policy propagation (30 seconds)..."
sleep 30

echo ""
echo "=== Policy Compliance Status ==="
oc get policy -n "$NS"

echo ""
echo "=== Detailed Policy Status ==="
for policy in policy-dns-operator-health policy-dns-corefile-integrity policy-dns-resource-exhaustion policy-dns-alerting-rule; do
  echo ""
  echo "--- $policy ---"
  oc get policy "$policy" -n "$NS" -o jsonpath='{.status.compliant}' 2>/dev/null || echo "pending"
  echo ""
done

echo ""
echo "=== Placement Decisions ==="
oc get placementdecision -n "$NS" -o yaml 2>/dev/null | grep -A5 "decisions:" || echo "No decisions yet"

echo ""
echo "Demo complete. Check RHACM console for full visualization."
