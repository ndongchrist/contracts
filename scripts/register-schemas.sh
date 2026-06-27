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
curl -fsS -X POST "$REGISTRY_URL/rules" \
  -H 'Content-Type: application/json' \
  -d '{"type":"COMPATIBILITY","config":"BACKWARD"}' \
  >/dev/null 2>&1 || \
curl -fsS -X PUT "$REGISTRY_URL/rules/COMPATIBILITY" \
  -H 'Content-Type: application/json' \
  -d '{"type":"COMPATIBILITY","config":"BACKWARD"}' >/dev/null

for schema in "$ROOT"/events/*/v*.json; do
  topic="$(basename "$(dirname "$schema")")"          # e.g. order.created
  artifact_id="${topic}-value"                         # <topic>-value convention
  echo "==> Registering $artifact_id from ${schema#$ROOT/}"
  curl -fsS -X POST "$REGISTRY_URL/groups/events/artifacts" \
    -H "Content-Type: application/json; artifactType=JSON" \
    -H "X-Registry-ArtifactId: ${artifact_id}" \
    -H "X-Registry-IfExists: RETURN_OR_UPDATE" \
    --data-binary "@${schema}" >/dev/null
done

echo "==> Done. Registered artifacts:"
curl -fsS "$REGISTRY_URL/groups/events/artifacts" | tr ',' '\n' | grep -i id || true
