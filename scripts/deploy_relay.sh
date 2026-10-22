#!/bin/bash
# Déploie le relais StreamHub (relay/worker.js) sur Cloudflare Workers.
# Usage : CF_API_TOKEN=… CF_ACCOUNT_ID=… scripts/deploy_relay.sh
# Le jeton et l'identifiant du compte ne sont jamais enregistrés dans le projet.
# (Plus d'espace Workers KV depuis la version 2.3.3 : le relais ne stocke plus rien.)
set -euo pipefail
: "${CF_API_TOKEN:?Il faut CF_API_TOKEN (jeton Cloudflare « Edit Cloudflare Workers »)}"
: "${CF_ACCOUNT_ID:?Il faut CF_ACCOUNT_ID}"
NAME=streamhub-relay
API="https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$NAME"
cd "$(dirname "$0")/.."

# Affiche « ok », ou l'erreur exacte de Cloudflare (code HTTP et message), puis arrête le script
check() {
  python3 -c '
import json, sys
body, _, http = sys.stdin.read().rpartition("\n")
try:
    answer = json.loads(body)
except ValueError:
    sys.exit("Échec (HTTP {}) : réponse illisible de Cloudflare".format(http))
if answer.get("success"):
    print("ok")
else:
    for e in answer.get("errors", []):
        print("Erreur Cloudflare {} : {}".format(e.get("code"), e.get("message")), file=sys.stderr)
    sys.exit("Échec (HTTP {})".format(http))
'
}

echo "Envoi de relay/worker.js…"
curl -s -w '\n%{http_code}' -X PUT "$API" -H "Authorization: Bearer $CF_API_TOKEN" \
  -F 'metadata={"main_module":"worker.js","compatibility_date":"2025-01-01","bindings":[]};type=application/json' \
  -F "worker.js=@relay/worker.js;type=application/javascript+module" | check

echo "Publication sur workers.dev…"
curl -s -w '\n%{http_code}' -X POST "$API/subdomain" -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  --data '{"enabled":true}' | check
