# PumpFunds Architecture

## Overview

PumpFunds is a **Solana copy trading platform** that allows users to automatically replicate trades made by experienced fund managers in real-time. The system monitors fund wallets, detects swap transactions, and executes identical trades for subscribed investors instantly.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter Mobile App                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Home       │  │  Portfolio   │  │   Settings   │          │
│  │  (Funds)     │  │ (Investments)│  │   (Wallet)   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└────────────────────────┬────────────────────────────────────────┘
                         │ REST API
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                      Node.js Backend Server                      │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │  Transaction     │  │  Copy Trade      │  │  ROI         │ │
│  │  Monitor         │  │  Engine          │  │  Calculator  │ │
│  │  (Helius API)    │  │  (Jupiter API)   │  │  (Cron)      │ │
│  └──────────────────┘  └──────────────────┘  └──────────────┘ │
│           │                      │                     │        │
└───────────┼──────────────────────┼─────────────────────┼────────┘
            │                      │                     │
            │                      │                     │
┌───────────▼──────────────────────▼─────────────────────▼────────┐
│                        Firebase Firestore                        │
│   ┌────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────┐ │
│   │ Users  │  │ Investments │  │ Transactions │  │  Funds   │ │
│   └────────┘  └─────────────┘  └──────────────┘  └──────────┘ │
└──────────────────────────────────────────────────────────────────┘
            │                      │
            │                      │
┌───────────▼──────────────────────▼───────────────────────────────┐
│                         Solana Blockchain                         │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────────┐           │
│   │ Fund Wallet │  │ User Wallet │  │ Jupiter DEX  │           │
│   └─────────────┘  └─────────────┘  └──────────────┘           │
└───────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Flutter Mobile App

**Technology:** Flutter 3.x, Dart, BLoC pattern

**Key Features:**
- Browse and search available trading funds
- Subscribe/unsubscribe to funds with investment amount
- Real-time portfolio tracking with PnL
- Manage Solana wallet (create, import, export)
- Enable/disable auto-approve for copy trades
- View transaction history

**State Management:**
```
├── HomeBloc (Funds listing)
├── PortfolioBloc (Investment tracking)
├── WalletBloc (Wallet operations)
└── TransactionBloc (Trade history)
```

### 2. Backend Server (Node.js)

**Technology:** Express.js, Node.js

**Responsibilities:**
- Transaction monitoring and detection
- Copy trade execution
- User wallet encryption/decryption
- ROI calculation
- API endpoints for mobile app

#### 2.1 Transaction Monitor

**File:** `transaction-monitor.js`

**Purpose:** Continuously polls Helius API to detect new swap transactions on fund wallets.

**Flow:**
```
┌──────────────────────────────────────────────────────────────┐
│                   Transaction Detection                       │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────┐
        │  Load funds with active         │
        │  investments from Firestore     │
        └─────────────┬───────────────────┘
                      │
                      ▼
        ┌─────────────────────────────────┐
        │  Poll each wallet every 5s      │
        │  via Helius API                 │
        │  (limit: 3 transactions)        │
        └─────────────┬───────────────────┘
                      │
                      ▼
        ┌─────────────────────────────────┐
        │  New SWAP detected?             │
        └─────────────┬───────────────────┘
                      │ Yes
                      ▼
        ┌─────────────────────────────────┐
        │  Trigger Copy Trade Engine      │
        └─────────────────────────────────┘
```

**Optimization:**
- Only monitors wallets with `isActive: true` investments
- Batch processing (5 wallets at a time)
- 3-second minimum interval per wallet
- Zero API calls when no active investments

#### 2.2 Copy Trade Engine

**File:** `server.js` → `executeCopyTrade()`

**Purpose:** Replicates fund manager's trade for all subscribed investors.

**Flow:**
```
┌─────────────────────────────────────────────────────────────────┐
│                      Copy Trade Execution                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
          ┌─────────────────────────────────────┐
          │  Parse transaction details          │
          │  (tokens, amounts, direction)       │
          └─────────────┬───────────────────────┘
                        │
                        ▼
          ┌─────────────────────────────────────┐
          │  Find all active investors          │
          │  for this fund                      │
          └─────────────┬───────────────────────┘
                        │
                        ▼
          ┌─────────────────────────────────────┐
          │  For each investor:                 │
          │  1. Decrypt private key             │
          │  2. Calculate proportional amount   │
          │  3. Get Jupiter quote               │
          │  4. Build & sign transaction        │
          │  5. Execute on Solana               │
          └─────────────┬───────────────────────┘
                        │
                        ▼
          ┌─────────────────────────────────────┐
          │  Store transaction in Firestore     │
          │  Send FCM notification to user      │
          └─────────────────────────────────────┘
```

**Key Features:**
- Parallel execution for all investors (instant)
- Proportional amount calculation based on investment
- Automatic slippage protection (0.5%)
- Priority fees for fast confirmation
- Retry logic (max 3 attempts)
- Duplicate transaction prevention

#### 2.3 Wallet Encryption

**File:** `sodium-encryption.js`

**Purpose:** Secure storage of user private keys using libsodium.

**Security:**
- XChaCha20-Poly1305 encryption
- User PIN-based key derivation
- Encrypted keys stored in Firestore
- Keys only decrypted in-memory during trades

#### 2.4 ROI Calculator

**File:** `server.js` → `calculateFundRoiWithHistory()`

**Purpose:** Calculate daily ROI for each fund based on transaction history.

**Schedule:** Runs every hour via cron job

**Calculation:**
```javascript
ROI = ((Total Value - Total Invested) / Total Invested) × 100
```

Stores 7-day historical data for performance charts.

### 3. Firebase Firestore

**Database Schema:**

```
firestore/
├── users/
│   ├── userId
│   │   ├── email: string
│   │   ├── encryptedPrivateKey: string
│   │   ├── publicKey: string
│   │   ├── salt: string
│   │   ├── fcmToken: string (for notifications)
│   │   └── createdAt: timestamp
│
├── funds/
│   ├── fundId
│   │   ├── name: string
│   │   ├── description: string
│   │   ├── walletAddresses: string[]
│   │   ├── roi7d: number
│   │   ├── roiHistory: number[] (7 days)
│   │   ├── imageUrl: string
│   │   └── lastUpdated: timestamp
│
├── investments/
│   ├── investmentId
│   │   ├── userId: string
│   │   ├── fundId: string
│   │   ├── amount: number (SOL)
│   │   ├── isActive: boolean
│   │   ├── autoApprove: boolean
│   │   └── createdAt: timestamp
│
└── transactions/
    ├── transactionId
    │   ├── userId: string
    │   ├── fundId: string
    │   ├── fundWallet: string
    │   ├── signature: string
    │   ├── type: "buy" | "sell"
    │   ├── tokenSymbol: string
    │   ├── tokenMint: string
    │   ├── amount: number (SOL)
    │   ├── totalValue: number
    │   └── timestamp: timestamp
```

### 4. External APIs

#### Helius API
**Purpose:** Transaction monitoring and webhooks
**Usage:** 
- Get transaction history for fund wallets
- Webhook notifications for real-time detection (optional)

#### Jupiter Aggregator API
**Purpose:** DEX aggregation for best swap rates
**Usage:**
- Get quotes for token swaps
- Build swap transactions
- Automatic routing across all Solana DEXs

#### Solana Tracker API
**Purpose:** Fetch real-time SOL price
**Usage:** Portfolio valuation in USD

## Data Flow

### User Subscribes to Fund

```
[App] User taps "Invest" on fund
  │
  ├─> Creates investment record in Firestore
  │   - fundId, userId, amount, isActive: true
  │
  └─> Backend detects new active investment
      │
      └─> Transaction Monitor adds wallet to polling list
          │
          └─> Webhook subscription updated (if Helius enabled)
```

### Fund Manager Makes Trade

```
[Solana] Fund wallet executes swap
  │
  ├─> [Helius] Detects transaction
  │   │
  │   └─> [Backend] Transaction Monitor polls API
  │       │
  │       └─> New SWAP transaction found
  │
  └─> [Backend] Copy Trade Engine triggered
      │
      ├─> Query Firestore for active investors
      │
      ├─> For each investor (parallel):
      │   │
      │   ├─> Decrypt wallet private key
      │   ├─> Calculate proportional amount
      │   ├─> Get Jupiter quote
      │   ├─> Build transaction
      │   ├─> Sign transaction
      │   ├─> Submit to Solana
      │   └─> Store in Firestore
      │
      └─> [App] Receives FCM notification
          │
          └─> Portfolio updates automatically
```

### User Views Portfolio

```
[App] Opens Portfolio screen
  │
  ├─> Fetches user investments from Firestore
  │
  ├─> Fetches wallet balance from Solana
  │
  ├─> Calculates total portfolio value
  │
  └─> Displays:
      - Current SOL balance
      - Active investments
      - Total invested
      - Total PnL
```

## Performance Optimizations

### 1. Zero-Credit Mode (Helius)
- **No active investments** → 0 API calls → $0 cost
- **Active investments** → Minimal polling → Low cost
- Webhook auto-cleanup every 30 minutes
- Webhook deleted entirely when no active users

### 2. Copy Trade Speed
- **Parallel execution:** All investors execute simultaneously
- **Priority fees:** Automatic priority fee calculation
- **Instant detection:** 3-5 second average detection time
- **Fast confirmation:** ~10-15 seconds on Solana

### 3. Scalability
- **Batch processing:** Polls 5 wallets concurrently
- **Rate limiting:** 3-second minimum per wallet
- **Memory management:** Cache cleanup every 10 minutes
- **Duplicate prevention:** In-memory signature tracking

## Security Considerations

### 1. Wallet Security
- Private keys encrypted with XChaCha20-Poly1305
- PIN-based key derivation (Argon2)
- Keys only decrypted in-memory during trades
- Never exposed to client or logs

### 2. API Security
- Environment variables for sensitive keys
- Firebase Admin SDK for secure Firestore access
- CORS enabled for mobile app only
- No exposed admin endpoints (can add auth if needed)

### 3. Transaction Safety
- Slippage protection (0.5% default)
- Duplicate transaction prevention
- Retry logic with exponential backoff
- Transaction signature verification

## Deployment

### Backend (Railway/VPS)
```bash
cd backend
npm install
node server.js
```

**Environment:** Node.js 18+
**Port:** 3000
**Uptime:** 24/7 required for transaction monitoring

### Mobile App (Android)
```bash
flutter build apk --release
flutter install
```

**Target:** Android 5.0+ (API 21+)
**Size:** ~55MB APK

### Firebase
- **Firestore:** Database
- **Authentication:** User management
- **Cloud Messaging:** Push notifications

## Monitoring & Logs

### Key Metrics
- Active investments count
- Helius API usage (calls/hour)
- Copy trade success rate
- Average detection time
- Transaction confirmation time

### Log Examples
```
✅ Loaded 3 wallets to monitor (only with active investments)
🔍 New transaction detected: signature123...
💱 Quote received: 1000000 → 950000
✅ Copy trade successful for user abc123
📱 Notification sent to user abc123
```

## Cron Jobs

### ROI Update (Hourly)
```javascript
cron.schedule('0 * * * *', updateAllFundsRoi);
```
Calculates 7-day ROI for all funds based on transaction history.

### Webhook Cleanup (Every 30 minutes)
```javascript
cron.schedule('*/30 * * * *', cleanupWebhooks);
```
Removes inactive wallets from Helius webhooks to save API credits.

## Future Enhancements

1. **Multi-fund investments:** Allow users to invest in multiple funds
2. **Custom slippage:** Let users configure their own slippage tolerance
3. **Stop-loss:** Automatic exit when losses exceed threshold
4. **Profit-taking:** Automatic partial exits at profit targets
5. **Social features:** Fund manager profiles, leaderboards, chat
6. **Analytics dashboard:** Detailed performance metrics and charts
7. **Web version:** Browser-based interface for desktop users

## Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.x, Dart, BLoC |
| **Backend** | Node.js, Express.js |
| **Database** | Firebase Firestore |
| **Blockchain** | Solana (mainnet-beta) |
| **APIs** | Helius, Jupiter, Solana Tracker |
| **Encryption** | libsodium (XChaCha20-Poly1305) |
| **Deployment** | Railway, Firebase |

## License

MIT License - See LICENSE file for details.
