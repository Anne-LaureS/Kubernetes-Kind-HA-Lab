#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CERT_DIR="ingress-certs"
AUTH_USER="labuser"
ROTATE=false
[ "${1:-}" = "--rotate" ] && ROTATE=true

echo "🔐 Certificat TLS auto-signé (si absent)..."
mkdir -p "$CERT_DIR"
if [ ! -f "$CERT_DIR/tls.crt" ]; then
  if ! OUT=$(openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
      -keyout "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.crt" \
      -subj "/CN=lab.localhost" \
      -addext "subjectAltName=DNS:grafana.localhost,DNS:wazuh.localhost,DNS:es.localhost" 2>&1); then
    echo "$OUT" >&2
    exit 1
  fi
  chmod 600 "$CERT_DIR/tls.key"
else
  echo "   déjà présent, on le garde."
fi

for ns in monitoring wazuh; do
  kubectl -n "$ns" create secret tls lab-ingress-tls \
    --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

echo "🔑 Authentification basique (Secret ingress-basic-auth)..."
if [ "$ROTATE" = false ] \
   && kubectl -n monitoring get secret ingress-basic-auth >/dev/null 2>&1; then
  echo "   déjà présent, mot de passe inchangé (pour en générer un nouveau : $0 --rotate)."
else
  PASSWORD="$(openssl rand -hex 12)"
  HASH="$(openssl passwd -apr1 "$PASSWORD")"
  kubectl -n monitoring create secret generic ingress-basic-auth \
    --from-literal=auth="${AUTH_USER}:${HASH}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "   identifiant  : $AUTH_USER"
  echo "   mot de passe : $PASSWORD"
  echo "   (affiché une seule fois, non stocké : seul son hash est dans le cluster)"
fi

echo "🚀 Application des Ingress..."
kubectl apply -f manifests/ingress-services.yaml

echo "✅ Accès (certificat auto-signé, avertissement navigateur attendu) :"
echo "   https://grafana.localhost   (login Grafana)"
echo "   https://es.localhost        (authentification basique)"
echo "   https://wazuh.localhost     (SSO Okta : lancer ensuite scripts/deploy-oauth2-proxy.sh)"
