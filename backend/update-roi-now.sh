#!/bin/bash

echo "🚀 Triggering ROI update for all funds..."
echo ""

# Call the admin endpoint to update ROI
curl -X POST http://localhost:3000/api/admin/update-roi \
  -H "Content-Type: application/json" \
  | jq '.'

echo ""
echo "✅ ROI update request sent!"
