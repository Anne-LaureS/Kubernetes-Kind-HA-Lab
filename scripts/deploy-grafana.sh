#!/bin/bash

GRAFANA_URL="http://127.0.0.1:8080"
API_KEY="glsa_CPhKOxHF0nK0XwBuMzEQFggwlUC2HKN9_33291448"

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
curl -X POST "$GRAFANA_URL/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @grafana/contact-points/email.json

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
  curl -X POST "$GRAFANA_URL/api/v1/provisioning/alert-rules" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @"$file"
done

echo "✅ Done!"
