#!/bin/bash

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:8081}"

echo "🚀 Importing Grafana configuration..."

# -------------------------
# 1. Import Dashboard
# -------------------------
echo "📊 Importing dashboard..."
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @grafana/dashboard.json

# -------------------------
# 2. Import Contact Points
# -------------------------
echo "📨 Importing contact points..."
: "${ALERT_EMAIL:?La variable ALERT_EMAIL doit être définie (adresse de notification)}"
envsubst < grafana/contact-points/email.json > /tmp/email.json
curl -X POST "$GRAFANA_URL/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/email.json

# -------------------------
# 3. Import Notification Policies
# -------------------------
echo "📬 Importing notification policies..."
curl -X PUT "$GRAFANA_URL/api/v1/provisioning/policies" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @grafana/notification-policies/default.json

# -------------------------
# 4. Import Alert Rules
# -------------------------
echo "🚨 Importing alert rules..."

for file in grafana/alerts/*.json; do
  echo "   → $file"
  uid=$(grep -o '"uid"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
  status=$(curl -s -o /tmp/alert-response.json -w "%{http_code}" -X PUT "$GRAFANA_URL/api/v1/provisioning/alert-rules/${uid}" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @"$file")
  if [[ "$status" == "404" ]]; then
    curl -X POST "$GRAFANA_URL/api/v1/provisioning/alert-rules" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      --data-binary @"$file"
  else
    cat /tmp/alert-response.json
  fi
  echo ""
done

echo "✅ Done!"
