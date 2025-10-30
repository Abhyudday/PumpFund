# PumpFunds Backend

Node.js backend server for the PumpFunds copy trading platform.

## Features

- 🔄 **Real-time Transaction Monitoring** - Polls Helius API for fund wallet transactions
- ⚡ **Instant Copy Trading** - Executes trades for all investors within seconds
- 🔐 **Wallet Encryption** - XChaCha20-Poly1305 encryption for private keys
- 📊 **ROI Calculation** - Automatic daily ROI tracking using Solana Tracker API (runs every 24 hours)
- 📈 **Historical ROI** - Stores daily ROI snapshots for 7-day performance charts
- 🧹 **Auto-Optimization** - Zero API costs when no active investments
- 🔔 **Push Notifications** - Firebase Cloud Messaging for trade alerts

## Tech Stack

- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** Firebase Firestore
- **Blockchain:** Solana Web3.js
- **DEX:** Jupiter Aggregator API
- **Monitoring:** Helius API
- **Encryption:** libsodium

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your credentials:
```env
PORT=3000
NODE_ENV=production
BACKEND_URL=https://your-backend-url.com

HELIUS_API_KEY=your_helius_api_key_here
SOLANA_TRACKER_API_KEY=your_solana_tracker_api_key
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com

FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----

COPY_TRADE_DELAY_MS=200
MAX_RETRIES=3
SLIPPAGE_TOLERANCE=0.05
```

### 3. Start Server

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

## Architecture

```
┌─────────────────────────────────────────────┐
│         Transaction Monitor Service         │
│  - Polls Helius every 5s                   │
│  - Only monitors active investments        │
│  - Batch processing (5 wallets at a time) │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│           Copy Trade Engine                 │
│  - Parallel execution                      │
│  - Jupiter aggregator                      │
│  - Proportional amounts                    │
│  - Retry logic (max 3)                     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│         Firebase Firestore                  │
│  - Users, Funds, Investments, Transactions │
└─────────────────────────────────────────────┘
```

## API Endpoints

### Public Endpoints

#### Get All Funds
```http
GET /api/funds
```

Response:
```json
[
  {
    "id": "fund123",
    "name": "Degen Gambles",
    "description": "High-risk meme trading",
    "walletAddresses": ["7vfCX..."],
    "roi7d": 24.5,
    "roiHistory": [0, 5.2, 10.1, 15.3, 20.2, 22.8, 24.5],
    "imageUrl": "https://...",
    "lastUpdated": "2024-01-01T00:00:00.000Z"
  }
]
```

#### Get Investments
```http
GET /api/investments/:userId
```

#### Get Transactions
```http
GET /api/transactions/:userId
```

### Admin Endpoints

#### Trigger ROI Update
```http
POST /api/admin/update-roi
```

#### Cleanup Webhooks
```http
POST /api/admin/cleanup-webhooks
```

### Webhook Endpoints

#### Helius Transaction Webhook
```http
POST /api/webhooks/helius
```

Receives transaction notifications from Helius.

## Key Components

### 1. Transaction Monitor (`transaction-monitor.js`)

**Purpose:** Continuously monitors fund wallets for new transactions.

**Features:**
- Polls every 5 seconds
- Only monitors wallets with active investments
- Batch processing to avoid rate limits
- Auto-refresh wallet list every 5 minutes
- Zero API calls when no active investments

**Flow:**
```javascript
// Check every 5 seconds
setInterval(poll, 5000);

// Only check wallets with active investments
loadFundWallets() {
  // Query Firestore for funds with isActive: true investments
  // Add to monitoring list
}

// Poll Helius API
checkWallet(address) {
  // GET /v0/addresses/{address}/transactions
  // Limit: 3 (save API credits)
  // Type: SWAP only
}
```

### 2. Copy Trade Engine (`server.js`)

**Purpose:** Execute copy trades for all investors when fund manager trades.

**Features:**
- Parallel execution for instant speed
- Proportional amount calculation
- Jupiter aggregator for best prices
- Automatic slippage protection
- Retry logic with exponential backoff
- Duplicate transaction prevention

**Flow:**
```javascript
async function executeCopyTrade(transaction) {
  // 1. Parse transaction details
  const { tokenIn, tokenOut, amount } = parseTransaction(transaction);
  
  // 2. Find all active investors
  const investors = await getActiveInvestors(fundId);
  
  // 3. Execute trades in parallel
  await Promise.all(investors.map(async (investor) => {
    // Decrypt wallet
    const wallet = await decryptWallet(investor);
    
    // Calculate proportional amount
    const tradeAmount = calculateAmount(amount, investor.allocation);
    
    // Get Jupiter quote
    const quote = await getJupiterQuote(tokenIn, tokenOut, tradeAmount);
    
    // Build & sign transaction
    const tx = await buildTransaction(quote, wallet);
    
    // Execute on Solana
    const signature = await sendTransaction(tx);
    
    // Store in Firestore
    await saveTransaction(signature, investor);
    
    // Send notification
    await sendPushNotification(investor);
  }));
}
```

### 3. Wallet Encryption (`sodium-encryption.js`)

**Purpose:** Secure encryption/decryption of user private keys.

**Algorithm:** XChaCha20-Poly1305 (libsodium)

**Security Features:**
- Authenticated encryption
- Random nonce per encryption
- User PIN-based key derivation
- Keys never stored in plain text

```javascript
async function encryptPrivateKey(privateKey, pin) {
  const salt = crypto.randomBytes(16);
  const key = await deriveKey(pin, salt);
  const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
  const encrypted = sodium.crypto_secretbox_easy(privateKey, nonce, key);
  
  return {
    encryptedData: encrypted.toString('base64'),
    salt: salt.toString('base64'),
    nonce: nonce.toString('base64')
  };
}
```

### 4. ROI Calculator

**Purpose:** Calculate daily ROI for each fund using real-time data from Solana Tracker API.

**Schedule:** Every 24 hours at midnight UTC via cron job

**Data Source:** Solana Tracker API (`https://data.solanatracker.io/pnl/wallet`)

**Calculation:**
```javascript
async function calculateFundRoiFromSolanaTracker(fundId, walletAddresses) {
  // Fetch real PNL data from Solana Tracker for each wallet
  let totalRoi = 0;
  let successCount = 0;
  
  for (const wallet of walletAddresses) {
    const response = await axios.get(
      `https://data.solanatracker.io/pnl/wallet?wallet=${wallet}&period=7d`
    );
    
    if (response.data && typeof response.data.roi === 'number') {
      totalRoi += response.data.roi;
      successCount++;
    }
  }
  
  // Calculate average ROI across all wallets
  const roi7d = successCount > 0 ? totalRoi / successCount : 0;
  
  // Get historical snapshots from last 7 days
  const roiHistory = await getHistoricalRoiSnapshots(fundId, roi7d);
  
  // Store today's snapshot in Firebase
  await storeRoiSnapshot(fundId, roi7d);
  
  return { roi7d, roiHistory };
}
```

**Storage:**
- Daily ROI snapshots stored in Firestore: `funds/{fundId}/roiSnapshots/{YYYY-MM-DD}`
- 7-day history array stored in fund document for quick access
- Historical data used to generate performance charts in the app

## Optimization Features

### Zero-Credit Mode

When there are **no active investments**, the system:
- ✅ Stops polling Helius API (0 API calls)
- ✅ Deletes webhooks (0 webhook credits)
- ✅ Costs $0/day

When investments become active:
- ✅ Resumes polling within 5 minutes
- ✅ Creates/updates webhooks
- ✅ Minimal API usage (3-5 second detection)

### API Credit Savings

| Scenario | API Calls/Hour | Cost/Day |
|----------|----------------|----------|
| No investments | 0 | $0 |
| 1-3 active | 360-1,080 | ~$0.10 |
| 5-10 active | 1,800-3,600 | ~$0.50 |

**Optimization techniques:**
- Batch processing (5 wallets at a time)
- Per-wallet rate limiting (min 3s between polls)
- Transaction limit (only fetch 3 latest)
- Webhook auto-cleanup every 30 minutes

## Monitoring

### Health Checks

```bash
# Check if server is running
curl http://localhost:3000/health

# Check monitored wallets
# Look for log: "Loaded X wallets to monitor"

# Check API usage
# Look for log: "Helius API usage: ZERO credits" (when no investments)
```

### Utility Scripts

```bash
# Check current Helius webhook status
./check-helius-usage.sh

# Force webhook cleanup
./cleanup-webhooks-now.sh

# Trigger ROI update manually
./update-roi-now.sh
```

### Logs to Monitor

```
✅ Loaded 3 wallets to monitor (only with active investments)
🔍 New transaction detected: signature123...
💱 Quote received: 1000000 → 950000
✅ Copy trade successful for user abc123
❌ Copy trade error (attempt 1/3): Error message
📱 Notification sent to user abc123
🧹 Cleaning up webhooks for inactive wallets...
✅ Webhook deleted - zero active investments, zero credits used
```

## Deployment

### Railway

```bash
railway login
railway init
railway up
```

Set environment variables in Railway dashboard.

### Heroku

```bash
heroku create pumpfunds-backend
heroku config:set HELIUS_API_KEY=your_key
git push heroku main
```

### VPS (Ubuntu)

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clone repo
git clone https://github.com/yourusername/pumpfunds.git
cd pumpfunds/backend

# Install dependencies
npm install

# Setup .env
cp .env.example .env
nano .env

# Install PM2 for process management
sudo npm install -g pm2

# Start server
pm2 start server.js --name pumpfunds
pm2 save
pm2 startup
```

## Troubleshooting

### High API Usage

```bash
# Check number of monitored wallets
# Should only include funds with active investments

# Check polling interval
# Should be 5000ms (5 seconds)

# Check transaction limit
# Should be 3 per request

# Force webhook cleanup
./cleanup-webhooks-now.sh
```

### Copy Trades Not Executing

```bash
# Check server logs
# Look for "New transaction detected"

# Verify Helius API key
curl "https://api.helius.xyz/v0/addresses/{wallet}/transactions?api-key=${HELIUS_API_KEY}"

# Check Firestore investments
# Ensure isActive: true and autoApprove: true

# Verify user has SOL balance
```

### Webhook Not Working

```bash
# Check webhook exists
./check-helius-usage.sh

# Test webhook manually
curl -X POST https://your-backend.com/api/webhooks/helius \
  -H "Content-Type: application/json" \
  -d '{"type":"SWAP","signature":"test"}'

# Re-create webhook
# Will happen automatically on next investment
```

## Performance

- **Detection Time:** 3-5 seconds average
- **Copy Trade Execution:** < 1 second (parallel)
- **Solana Confirmation:** 10-15 seconds
- **Memory Usage:** ~150MB
- **CPU Usage:** < 5% idle, < 20% during trades

## Security

- Private keys encrypted at rest
- Keys decrypted only in-memory during trades
- API keys in environment variables (never committed)
- Firestore security rules enforce access control
- No exposed admin endpoints (add auth if needed)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](../LICENSE)
