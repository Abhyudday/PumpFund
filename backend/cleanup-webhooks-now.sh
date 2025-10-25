#!/bin/bash

echo "🧹 Triggering Webhook Cleanup..."
echo ""

# Call the admin endpoint to clean up webhooks
curl -X POST http://localhost:3000/api/admin/cleanup-webhooks \
  -H "Content-Type: application/json" \
  | jq '.'

echo ""
echo "✅ Cleanup request sent!"
echo ""
echo "💡 Check server logs for details"
echo "   Look for: 'Webhook deleted' or 'Webhook cleaned up'"
