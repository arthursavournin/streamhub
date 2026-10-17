#!/bin/bash
# Déploie le relais StreamHub (relay/worker.js) sur Cloudflare Workers.
# Usage : CF_API_TOKEN=… CF_ACCOUNT_ID=… CF_KV_NAMESPACE_ID=… scripts/deploy_relay.sh
# Le jeton et les identifiants du compte ne sont jamais enregistrés dans le projet.
# CF_KV_NAMESPACE_ID : identifiant de l'espace Workers KV de la synchronisation (tableau de bord Cloudflare →
# Workers KV → streamhub-sync).
set -euo pipefail
: "${CF_API_TOKEN:?Il faut CF_API_TOKEN (jeton Cloudflare « Edit Cloudflare Workers »)}"
: "${CF_ACCOUNT_ID:?Il faut CF_ACCOUNT_ID}"
: "${CF_KV_NAMESPACE_ID:?Il faut CF_KV_NAMESPACE_ID (espace Workers KV de la synchronisation)}"
NAME=streamhub-relay
API="https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$NAME"
cd "$(dirname "$0")/.."

echo "Envoi de relay/worker.js…"
curl -sf -X PUT "$API" -H "Authorization: Bearer $CF_API_TOKEN" \
  -F 'metadata={"main_module":"worker.js","compatibility_date":"2025-01-01","bindings":[{"type":"kv_namespace","name":"SYNC","namespace_id":"'"$CF_KV_NAMESPACE_ID"'"}]};type=application/json' \
  -F "worker.js=@relay/worker.js;type=application/javascript+module" | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if d['success'] else d['errors'])"

echo "Publication sur workers.dev…"
curl -sf -X POST "$API/subdomain" -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  --data '{"enabled":true}' | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if d['success'] else d['errors'])"
