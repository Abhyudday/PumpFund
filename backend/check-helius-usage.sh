#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🔍 Checking Helius API Usage"
echo "=============================="
echo ""

if [ -z "$HELIUS_API_KEY" ]; then
    echo "❌ HELIUS_API_KEY not set in .env"
    exit 1
fi

echo "📊 Current Helius Webhooks:"
echo ""

# Get all webhooks
curl -s "https://api.helius.xyz/v0/webhooks?api-key=$HELIUS_API_KEY" | jq '.'

echo ""
echo "=============================="
echo ""
echo "💡 Interpretation:"
echo "   - If no webhooks exist: ✅ ZERO credits being used"
echo "   - If webhook has 0 addresses: ⚠️  Webhook exists but monitoring nothing"
echo "   - If webhook has addresses: 📍 Actively monitoring those wallets"
echo ""
echo "💰 Cost per wallet: ~1-2 credits per transaction detected"
echo "   With 0 wallets: 0 credits/hour"
echo "   With 5 active wallets: ~5-10 credits/hour (depends on activity)"
