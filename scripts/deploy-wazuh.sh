#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "🔐 Génération des certificats Wazuh (si absents)..."
if [ ! -f wazuh/certs/indexer_cluster/root-ca.pem ]; then
  (cd wazuh/certs/indexer_cluster && bash generate_certs.sh)
else
  echo "   déjà présents, on garde les certificats existants."
fi
if [ ! -f wazuh/certs/dashboard_http/cert.pem ]; then
  (cd wazuh/certs/dashboard_http && bash generate_certs.sh)
else
  echo "   déjà présents, on garde les certificats existants."
fi

echo "🚀 Déploiement du stack Wazuh (namespace wazuh)..."
kubectl apply -k wazuh-envs/kind-env

echo "⏳ Attente des pods (peut prendre plusieurs minutes le temps que l'indexer initialise la sécurité)..."
kubectl -n wazuh rollout status statefulset/wazuh-indexer --timeout=300s
kubectl -n wazuh rollout status statefulset/wazuh-manager-master --timeout=300s
kubectl -n wazuh rollout status statefulset/wazuh-manager-worker --timeout=300s
kubectl -n wazuh rollout status deployment/wazuh-dashboard --timeout=300s

echo "✅ Wazuh est déployé. Accès dashboard :"
echo "   kubectl -n wazuh port-forward --address 127.0.0.1 svc/dashboard 8443:443"
echo "   https://127.0.0.1:8443  (certificat auto-signé, avertissement navigateur attendu)"
