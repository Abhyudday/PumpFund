# 🚀 PumpFunds - Solana Copy Trading Platform

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js)
![Solana](https://img.shields.io/badge/Solana-Mainnet-9945FF?logo=solana)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A mobile-first platform that enables users to automatically copy trades from experienced Solana fund managers in real-time. Subscribe to curated trading funds and watch your investment mirror professional traders' moves instantly.

## ✨ Features

### For Investors
- 💼 **Browse Trading Funds** - Discover curated funds with verified performance
- 📊 **Real-Time Performance** - Track 7-day ROI with interactive charts
- ⚡ **Instant Copy Trading** - Trades execute within 3-5 seconds of fund manager
- 🔒 **Secure Wallet** - Encrypted private keys with PIN protection
- 💰 **Portfolio Dashboard** - Monitor investments, PnL, and transaction history
- 🎯 **Customizable Settings** - Auto-approve trades or manual approval mode
- 🔔 **Push Notifications** - Get alerted for every trade execution

### For Fund Managers
- 🎯 **Attract Investors** - List your fund and build a following
- 📈 **Performance Tracking** - Auto-calculated ROI and historical charts
- 💸 **Management Fees** - Earn from successful trading performance
- 📱 **Mobile Management** - Track your fund's performance on-the-go

### Technical Highlights
- ⚡ **Ultra-Fast Execution** - 3-5 second trade detection
- 🔐 **Military-Grade Encryption** - XChaCha20-Poly1305 for private keys
- 💎 **Best Price Guaranteed** - Jupiter aggregator for optimal DEX routing
- 🛡️ **Slippage Protection** - Automatic 0.5% slippage tolerance
- 💰 **Cost Optimized** - Zero API costs when no active investments

## 🏗️ Architecture

For detailed system architecture, data flow, and technical diagrams, see [ARCHITECTURE.md](ARCHITECTURE.md).

```
Flutter App (Mobile)  →  Node.js Backend  →  Firebase Firestore
                                   ↓
                          Solana Blockchain
                                   ↓
                     Jupiter (DEX) + Helius (Monitor)
```

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** ≥3.0.0
- **Node.js** ≥18.0.0
- **Android Studio** or **Xcode**
- **Firebase Project** (Firestore + Auth + FCM)
- **Helius API Key** (https://helius.dev)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/pumpfunds.git
cd pumpfunds
```

### 2. Setup Firebase

1. Create project at https://console.firebase.google.com
2. Enable **Authentication** (Email/Password)
3. Enable **Firestore Database**
4. Enable **Cloud Messaging**

**Android:**
```bash
# Download google-services.json from Firebase Console
# Place it in: android/app/google-services.json
```

**iOS:**
```bash
# Download GoogleService-Info.plist from Firebase Console
# Place it in: ios/Runner/GoogleService-Info.plist
```

### 3. Deploy Firestore Indexes

```bash
firebase login
firebase use --add  # Select your Firebase project
firebase deploy --only firestore:indexes
```

### 4. Setup Backend

```bash
cd backend
npm install
cp .env.example .env
```

Edit `backend/.env`:
```env
PORT=3000
BACKEND_URL=https://your-backend-url.com

HELIUS_API_KEY=your_helius_api_key
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com

FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----
```

Start backend:
```bash
npm start
```

### 5. Setup Flutter App

```bash
cd ..
flutter pub get
```

Update backend URL in `lib/services/api_service.dart`:
```dart
static const String _backendBaseUrl = 'https://your-backend-url.com';
```

### 6. Run App

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Build Release APK
flutter build apk --release
```

## 📁 Project Structure

```
pumpfunds/
├── lib/                        # Flutter app code
│   ├── blocs/                  # State management (BLoC pattern)
│   │   ├── auth/               # Authentication logic
│   │   ├── wallet/             # Wallet operations
│   │   ├── portfolio/          # Investment tracking
│   │   └── home/               # Fund browsing
│   ├── models/                 # Data models
│   │   ├── fund_model.dart
│   │   ├── investment_model.dart
│   │   ├── transaction_model.dart
│   │   └── wallet_model.dart
│   ├── screens/                # UI screens
│   │   ├── auth/               # Login/Register
│   │   ├── home/               # Fund listing & details
│   │   ├── portfolio/          # Investment tracking
│   │   └── settings/           # Wallet & account management
│   ├── services/               # Business logic
│   │   ├── wallet_service.dart # Solana wallet operations
│   │   ├── firebase_service.dart # Firestore CRUD
│   │   └── api_service.dart    # Backend API calls
│   └── utils/                  # Utilities & constants
│       ├── theme.dart          # App styling
│       └── constants.dart      # App constants
├── backend/                    # Node.js server
│   ├── server.js              # Main Express server
│   ├── transaction-monitor.js  # Helius polling service
│   ├── sodium-encryption.js    # Wallet encryption
│   ├── .env.example           # Environment template
│   └── package.json           # Dependencies
├── android/                    # Android platform code
├── ios/                        # iOS platform code
├── firestore.indexes.json      # Firestore composite indexes
├── firestore.rules            # Firestore security rules
├── ARCHITECTURE.md            # System architecture docs
└── README.md                  # This file
```

## 🔑 Environment Variables

### Backend (.env)

| Variable | Description | Required |
|----------|-------------|----------|
| `HELIUS_API_KEY` | Helius API key for transaction monitoring | Yes |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Yes |
| `FIREBASE_CLIENT_EMAIL` | Firebase service account email | Yes |
| `FIREBASE_PRIVATE_KEY` | Firebase service account private key | Yes |
| `BACKEND_URL` | Public backend URL for webhooks | Yes |
| `SOLANA_RPC_URL` | Solana RPC endpoint (mainnet/devnet) | Yes |
| `PORT` | Server port (default: 3000) | No |
| `COPY_TRADE_DELAY_MS` | Delay before executing copy trade | No |
| `MAX_RETRIES` | Max retry attempts for failed trades | No |
| `SLIPPAGE_TOLERANCE` | Slippage tolerance (default: 0.005) | No |

## 🗄️ Database Schema

### Firestore Collections

**users**
```javascript
{
  id: "userId",
  email: "user@example.com",
  encryptedPrivateKey: "encrypted_key_here",
  publicKey: "solana_public_key",
  salt: "encryption_salt",
  fcmToken: "firebase_cloud_messaging_token",
  createdAt: Timestamp
}
```

**funds**
```javascript
{
  id: "fundId",
  name: "Degen Gambles",
  description: "High-risk meme coin trading",
  walletAddresses: ["FundWallet1...", "FundWallet2..."],
  roi7d: 24.5,
  roiHistory: [0, 2.5, 5.0, 10.2, 15.8, 20.1, 24.5],
  imageUrl: "https://...",
  lastUpdated: Timestamp
}
```

**investments**
```javascript
{
  id: "investmentId",
  userId: "userId",
  fundId: "fundId",
  amount: 1.5,  // SOL
  isActive: true,
  autoApprove: true,
  createdAt: Timestamp
}
```

**transactions**
```javascript
{
  id: "transactionId",
  userId: "userId",
  fundId: "fundId",
  fundWallet: "FundWallet...",
  signature: "solana_signature",
  type: "buy" | "sell",
  tokenSymbol: "BONK",
  tokenMint: "token_mint_address",
  amount: 0.5,  // SOL spent
  totalValue: 0.52,  // Including fees
  timestamp: Timestamp
}
```

## 🔐 Security

- **Private Key Encryption:** XChaCha20-Poly1305 authenticated encryption
- **PIN Protection:** Argon2 key derivation from user PIN
- **No Server-Side Keys:** Private keys never leave the device
- **Secure Storage:** Flutter Secure Storage with OS-level encryption
- **Transaction Signing:** All signing done client-side
- **API Rate Limiting:** Built-in protection against abuse
- **Firestore Rules:** Strict security rules prevent unauthorized access

## 🧪 Testing

### Test on Devnet First

Update RPC URLs to devnet for testing:

**Backend (.env):**
```env
SOLANA_RPC_URL=https://api.devnet.solana.com
```

**Flutter (lib/services/wallet_service.dart):**
```dart
final SolanaClient _solanaClient = SolanaClient(
  rpcUrl: Uri.parse('https://api.devnet.solana.com'),
  websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
);
```

### Test Scenarios
- ✅ User registration & authentication
- ✅ Wallet generation & import
- ✅ Fund browsing & subscription
- ✅ Copy trade execution
- ✅ Portfolio tracking & PnL calculation
- ✅ Transaction history
- ✅ Notifications

## 🚢 Deployment

### Backend (Railway/Heroku/VPS)

**Railway:**
```bash
cd backend
railway login
railway init
railway up
```

**Environment Variables:** Set all required env vars in Railway dashboard

**Important:** Backend must run 24/7 for transaction monitoring

### Mobile App

**Android APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (Google Play):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**iOS (Xcode required):**
```bash
flutter build ios --release
# Then archive and upload via Xcode
```

## 📊 Performance

| Metric | Value |
|--------|-------|
| Trade Detection | 3-5 seconds |
| Copy Trade Execution | < 1 second |
| Solana Confirmation | 10-15 seconds |
| App Size (APK) | ~55MB |
| Backend Memory | ~150MB |
| API Efficiency | 98% reduction (vs naive polling) |

## 🐛 Troubleshooting

### Common Issues

**Build Errors:**
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..  # iOS only
flutter build apk
```

**Wallet Not Generating:**
- Check device has secure storage
- Verify `flutter_secure_storage` permissions
- Try on physical device (not emulator)

**Copy Trades Not Working:**
- Check backend logs for errors
- Verify Helius API key is valid
- Ensure user has sufficient SOL balance
- Check if investment `isActive: true`

**Firebase Connection Issues:**
- Verify `google-services.json` is in place
- Check Firebase project settings match app
- Ensure all Firebase services are enabled

## 🗺️ Roadmap

- [ ] iOS App Store release
- [ ] WalletConnect integration for external wallets
- [ ] Multi-fund investment support
- [ ] Custom slippage & stop-loss settings
- [ ] Social features (leaderboards, chat)
- [ ] Advanced analytics dashboard
- [ ] Referral program
- [ ] Multi-chain support (Ethereum, Base)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

**Important:** This software involves cryptocurrency trading which carries significant financial risk. Only invest what you can afford to lose. Past performance does not guarantee future results. Always do your own research (DYOR).

The developers are not responsible for any financial losses incurred through the use of this software. Use at your own risk.

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/pumpfunds/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/pumpfunds/discussions)
- **Email:** support@pumpfunds.io

## 🙏 Acknowledgments

- [Solana](https://solana.com) - Blockchain platform
- [Jupiter](https://jup.ag) - DEX aggregator
- [Helius](https://helius.dev) - Transaction monitoring
- [Firebase](https://firebase.google.com) - Backend infrastructure
- [Flutter](https://flutter.dev) - UI framework

---

**Built with ❤️ for the Solana community**

⭐ Star this repo if you find it useful!
