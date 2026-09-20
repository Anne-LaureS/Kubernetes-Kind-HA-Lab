#!/bin/bash
# Déploie oauth2-proxy (SSO Okta) devant le dashboard Wazuh.
#
# Prérequis : une application OIDC "Web" dans Okta avec
#   - Sign-in redirect URI : https://wazuh.localhost/oauth2/callback
#   - Grant type           : Authorization Code
#   - Assignments          : uniquement les comptes autorisés à ouvrir Wazuh
#
# OKTA_ISSUER est l'URL de l'organisation Okta (https://<tenant>.okta.com, serveur d'autorisation de
# l'organisation : aucune politique d'accès supplémentaire à créer).
#
# Les valeurs peuvent être passées par variables d'environnement (OKTA_ISSUER, OKTA_CLIENT_ID,
# OKTA_CLIENT_SECRET) ; sinon elles sont demandées (le secret sans écho). Rien n'est écrit sur disque.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

NS="wazuh"

if [ -z "${OKTA_ISSUER:-}" ]; then
  read -r -p "Issuer Okta (ex. https://<tenant>.okta.com) : " OKTA_ISSUER
fi
if [ -z "${OKTA_CLIENT_ID:-}" ]; then
  read -r -p "Client ID : " OKTA_CLIENT_ID
fi
if [ -z "${OKTA_CLIENT_SECRET:-}" ]; then
  read -r -s -p "Client secret : " OKTA_CLIENT_SECRET
  echo
fi
OKTA_ISSUER="${OKTA_ISSUER%/}"

for v in OKTA_ISSUER OKTA_CLIENT_ID OKTA_CLIENT_SECRET; do
  [ -n "${!v}" ] || { echo "❌ $v est vide." >&2; exit 1; }
done
case "$OKTA_ISSUER" in
  https://*) ;;
  *) echo "❌ L'issuer doit commencer par https://" >&2; exit 1 ;;
esac

# Le certificat TLS de l'Ingress et le Secret lab-ingress-tls viennent de deploy-ingress.sh
kubectl -n "$NS" get secret lab-ingress-tls >/dev/null 2>&1 \
  || { echo "❌ Secret lab-ingress-tls absent dans '$NS' : lancer d'abord scripts/deploy-ingress.sh" >&2; exit 1; }

echo "🔑 Secret oauth2-proxy..."
# Le secret de cookie est conservé d'un déploiement à l'autre (sinon les sessions sont invalidées)
COOKIE_SECRET="$(kubectl -n "$NS" get secret oauth2-proxy -o jsonpath='{.data.cookie-secret}' 2>/dev/null | base64 -d || true)"
if [ -z "$COOKIE_SECRET" ]; then
  COOKIE_SECRET="$(head -c 32 /dev/urandom | base64 | tr -d '\n' | tr '+/' '-_')"
fi
kubectl -n "$NS" create secret generic oauth2-proxy \
  --from-literal=client-id="$OKTA_CLIENT_ID" \
  --from-literal=client-secret="$OKTA_CLIENT_SECRET" \
  --from-literal=cookie-secret="$COOKIE_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$NS" create configmap oauth2-proxy-config \
  --from-literal=issuer-url="$OKTA_ISSUER" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "🚀 Application de oauth2-proxy et des Ingress Wazuh..."
kubectl apply -f manifests/oauth2-proxy.yaml
# Relance pour prendre en compte un éventuel changement d'issuer / de client
kubectl -n "$NS" rollout restart deployment/oauth2-proxy >/dev/null
kubectl -n "$NS" rollout status deployment/oauth2-proxy --timeout=120s

echo "✅ https://wazuh.localhost  (connexion Okta, puis login Wazuh)"
