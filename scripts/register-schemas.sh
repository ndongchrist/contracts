#!/usr/bin/env bash
# Register every event schema in this repo to Apicurio and enforce BACKWARD
# compatibility globally — a producer literally cannot deploy a breaking change.
# Run from CI (or locally with the registry port-forwarded).
#
#   REGISTRY_URL=http://localhost:8080/apis/registry/v2 ./scripts/register-schemas.sh
set -euo pipefail

REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080/apis/registry/v2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Setting global compatibility rule to BACKWARD"
# Apicurio v2 global rules live under /admin/rules. POST creates; if it already
# exists (409) fall back to PUT.
curl -fsS -X POST "$REGISTRY_URL/admin/rules" \
  -H 'Content-Type: application/json' \
  -d '{"type":"COMPATIBILITY","config":"BACKWARD"}' >/dev/null 2>&1 || \
curl -fsS -X PUT "$REGISTRY_URL/admin/rules/COMPATIBILITY" \
  -H 'Content-Type: application/json' \
  -d '{"type":"COMPATIBILITY","config":"BACKWARD"}' >/dev/null

for schema in "$ROOT"/events/*/v*.json; do
  topic="$(basename "$(dirname "$schema")")"          # e.g. order.created
  artifact_id="${topic}-value"                         # <topic>-value convention
  echo "==> Registering $artifact_id from ${schema#$ROOT/}"
  curl -fsS -X POST "$REGISTRY_URL/groups/events/artifacts?ifExists=UPDATE" \
    -H "Content-Type: application/json" \
    -H "X-Registry-ArtifactType: JSON" \
    -H "X-Registry-ArtifactId: ${artifact_id}" \
    --data-binary "@${schema}" >/dev/null
done

echo "==> Done. Registered artifacts:"
curl -fsS "$REGISTRY_URL/groups/events/artifacts" | tr ',' '\n' | grep -i id || true
