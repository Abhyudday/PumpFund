const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const dotenv = require('dotenv');
const admin = require('firebase-admin');
const cron = require('node-cron');
const axios = require('axios');
const { Connection, PublicKey, Keypair, Transaction, SystemProgram, VersionedTransaction } = require('@solana/web3.js');
const { getAssociatedTokenAddress, getAccount } = require('@solana/spl-token');
const TransactionMonitor = require('./transaction-monitor');
const sodiumEncryption = require('./sodium-encryption');

dotenv.config();

// Initialize Firebase Admin
try {
  const serviceAccount = {
    project_id: process.env.FIREBASE_PROJECT_ID,
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
    private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  };

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  
  console.log('✅ Firebase Admin initialized successfully');
} catch (error) {
  console.error('❌ Firebase initialization error:', error.message);
  console.error('Full error:', error);
  process.exit(1);
}

const db = admin.firestore();
const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Solana connection with commitment level - using 'processed' for instant execution
// For best performance, use a premium RPC like Helius, QuickNode, or Triton
// Set SOLANA_RPC_URL in .env to your premium RPC endpoint
const connection = new Connection(
  process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
  { 
    commitment: 'processed',
    confirmTransactionInitialTimeout: 60000 // 60 seconds timeout
  }
);

// Jupiter API configuration - Using v1 API endpoints (Legacy Swap API)
const JUPITER_QUOTE_API = 'https://lite-api.jup.ag/swap/v1/quote';
const JUPITER_SWAP_API = 'https://lite-api.jup.ag/swap/v1/swap';
const HELIUS_WEBHOOK_API = 'https://api.helius.xyz/v0/webhooks';
const SOL_MINT = 'So11111111111111111111111111111111111111112';

// Copy trading configuration
const COPY_TRADE_DELAY_MS = 0; // No delay
const MAX_RETRIES = parseInt(process.env.MAX_RETRIES) || 3;
const SLIPPAGE_BPS = Math.floor((parseFloat(process.env.SLIPPAGE_TOLERANCE) || 0.05) * 10000); // Convert to basis points (1% = 100 BPS)

// Decrypt data using libsodium (matches Flutter sodium_libs)
async function decryptData(encryptedData) {
  try {
    return await sodiumEncryption.decryptData(encryptedData);
  } catch (error) {
    console.error('Decryption error:', error.message);
    throw new Error(`Failed to decrypt data: ${error.message}`);
  }
}

// In-memory storage for subscriptions and processed transactions
const activeSubscriptions = new Map();
const processedTransactions = new Map(); // Cache: userId-fundId-signature -> timestamp

// Clean processed transactions cache every 5 minutes
setInterval(() => {
  const now = Date.now();
  const fiveMinutesAgo = now - 300000;
  
  for (const [key, timestamp] of processedTransactions.entries()) {
    if (timestamp < fiveMinutesAgo) {
      processedTransactions.delete(key);
    }
  }
  
  if (processedTransactions.size > 0) {
    console.log(`🧹 Cleaned old transaction cache. Current size: ${processedTransactions.size}`);
  }
}, 300000);

// Initialize transaction monitor
let transactionMonitor = null;

// ==================== ROUTES ====================

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Subscribe user to a fund for copy trading
app.post('/api/subscribe', async (req, res) => {
  try {
    const { userId, fundId, allocatedAmount, purchaseSizePercentage, autoApprove } = req.body;

    if (!userId || !fundId || !allocatedAmount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Get fund details
    const fundDoc = await db.collection('funds').doc(fundId).get();
    if (!fundDoc.exists) {
      return res.status(404).json({ error: 'Fund not found' });
    }

    const fund = fundDoc.data();
    
    // Check if investment already exists
    const existingInvestment = await db.collection('investments')
      .where('userId', '==', userId)
      .where('fundId', '==', fundId)
      .get();

    if (!existingInvestment.empty) {
      // Update existing investment
      const investmentDoc = existingInvestment.docs[0];
      await db.collection('investments').doc(investmentDoc.id).update({
        allocatedAmount,
        purchaseSizePercentage: purchaseSizePercentage || 100,
        autoApprove: autoApprove !== undefined ? autoApprove : true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Updated investment for user ${userId} in fund ${fundId}`);
    } else {
      // Create new investment record in Firestore
      await db.collection('investments').add({
        userId,
        fundId,
        allocatedAmount,
        purchaseSizePercentage: purchaseSizePercentage || 100,
        autoApprove: autoApprove !== undefined ? autoApprove : true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Created new investment for user ${userId} in fund ${fundId}`);
    }
    
    // Also store in memory for quick access (optional)
    activeSubscriptions.set(`${userId}-${fundId}`, {
      userId,
      fundId,
      allocatedAmount,
      wallets: fund.walletAddresses,
      createdAt: new Date(),
    });

    // Subscribe to Helius webhooks for fund wallets
    await subscribeToWallets(fund.walletAddresses, fundId);

    // Add wallets to transaction monitor immediately
    if (transactionMonitor) {
      for (const wallet of fund.walletAddresses) {
        await transactionMonitor.addWallet(wallet, fundId);
      }
    }

    console.log(`✅ User ${userId} subscribed to fund ${fundId} with autoApprove: ${autoApprove}`);
    res.json({ success: true, message: 'Subscribed to fund successfully' });
  } catch (error) {
    console.error('Subscribe error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Unsubscribe user from a fund
app.post('/api/unsubscribe', async (req, res) => {
  try {
    const { userId, fundId } = req.body;

    if (!userId || !fundId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Delete investment from Firestore
    const investmentSnapshot = await db.collection('investments')
      .where('userId', '==', userId)
      .where('fundId', '==', fundId)
      .get();

    if (!investmentSnapshot.empty) {
      const batch = db.batch();
      investmentSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`✅ Deleted investment record for user ${userId} from fund ${fundId}`);
    }

    // Also remove from memory
    activeSubscriptions.delete(`${userId}-${fundId}`);

    console.log(`✅ User ${userId} unsubscribed from fund ${fundId}`);
    res.json({ success: true, message: 'Unsubscribed from fund successfully' });
  } catch (error) {
    console.error('Unsubscribe error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update investment settings
app.post('/api/update-investment', async (req, res) => {
  try {
    const { userId, fundId, allocatedAmount, purchaseSizePercentage, autoApprove, isActive } = req.body;

    if (!userId || !fundId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Find the investment
    const investmentSnapshot = await db.collection('investments')
      .where('userId', '==', userId)
      .where('fundId', '==', fundId)
      .get();

    if (investmentSnapshot.empty) {
      return res.status(404).json({ error: 'Investment not found' });
    }

    // Update investment
    const investmentDoc = investmentSnapshot.docs[0];
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (allocatedAmount !== undefined) updateData.allocatedAmount = allocatedAmount;
    if (purchaseSizePercentage !== undefined) updateData.purchaseSizePercentage = purchaseSizePercentage;
    if (autoApprove !== undefined) updateData.autoApprove = autoApprove;
    if (isActive !== undefined) updateData.isActive = isActive;

    await db.collection('investments').doc(investmentDoc.id).update(updateData);

    console.log(`✅ Updated investment for user ${userId} in fund ${fundId}`);
    res.json({ success: true, message: 'Investment updated successfully' });
  } catch (error) {
    console.error('Update investment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helius webhook endpoint for transaction notifications
app.post('/api/webhooks/helius', async (req, res) => {
  try {
    const transactions = req.body;

    console.log(`\n${'='.repeat(60)}`);
    console.log(`📩 Received ${transactions.length} transactions from Helius webhook`);
    console.log(`${'='.repeat(60)}\n`);

    // Respond immediately to Helius to prevent timeout
    res.json({ success: true });

    // Process transactions in background for instant response
    for (const tx of transactions) {
      processTransaction(tx).catch(error => {
        console.error('❌ Background transaction processing error:', error);
      });
    }

  } catch (error) {
    console.error('❌ Webhook error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: error.message });
    }
  }
});

// Get active subscriptions (admin endpoint)
app.get('/api/admin/subscriptions', (req, res) => {
  const subscriptions = Array.from(activeSubscriptions.values());
  res.json({ count: subscriptions.length, subscriptions });
});

// Admin: Get all funds
app.get('/api/admin/funds', async (req, res) => {
  try {
    const fundsSnapshot = await db.collection('funds').get();
    const funds = [];
    
    fundsSnapshot.forEach((doc) => {
      funds.push({ id: doc.id, ...doc.data() });
    });

    res.json({ count: funds.length, funds });
  } catch (error) {
    console.error('Get funds error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Admin: Create fund
app.post('/api/admin/funds', async (req, res) => {
  try {
    const { name, description, imageUrl, walletAddresses } = req.body;

    if (!name || !description || !walletAddresses || walletAddresses.length === 0) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Calculate ROI for the fund
    const roi7d = await calculateFundRoi(walletAddresses);

    const fundData = {
      name,
      description,
      imageUrl: imageUrl || '',
      walletAddresses,
      roi7d,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('funds').add(fundData);
    
    res.json({ 
      success: true, 
      fundId: docRef.id,
      message: 'Fund created successfully' 
    });
  } catch (error) {
    console.error('Create fund error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Admin: Update fund
app.put('/api/admin/funds/:fundId', async (req, res) => {
  try {
    const { fundId } = req.params;
    const { name, description, imageUrl, walletAddresses } = req.body;

    const fundDoc = await db.collection('funds').doc(fundId).get();
    if (!fundDoc.exists) {
      return res.status(404).json({ error: 'Fund not found' });
    }

    const updateData = {
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (name) updateData.name = name;
    if (description) updateData.description = description;
    if (imageUrl !== undefined) updateData.imageUrl = imageUrl;
    
    if (walletAddresses && walletAddresses.length > 0) {
      updateData.walletAddresses = walletAddresses;
      // Recalculate ROI
      updateData.roi7d = await calculateFundRoi(walletAddresses);
    }

    await db.collection('funds').doc(fundId).update(updateData);
    
    res.json({ success: true, message: 'Fund updated successfully' });
  } catch (error) {
    console.error('Update fund error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Admin: Delete fund
app.delete('/api/admin/funds/:fundId', async (req, res) => {
  try {
    const { fundId } = req.params;

    const fundDoc = await db.collection('funds').doc(fundId).get();
    if (!fundDoc.exists) {
      return res.status(404).json({ error: 'Fund not found' });
    }

    await db.collection('funds').doc(fundId).delete();
    
    res.json({ success: true, message: 'Fund deleted successfully' });
  } catch (error) {
    console.error('Delete fund error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Admin: Manually trigger ROI update
app.post('/api/admin/update-roi', async (req, res) => {
  try {
    await updateAllFundsRoi();
    res.json({ success: true, message: 'ROI update completed' });
  } catch (error) {
    console.error('Manual ROI update error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Admin: Manually trigger webhook cleanup
app.post('/api/admin/cleanup-webhooks', async (req, res) => {
  try {
    await cleanupWebhooks();
    res.json({ success: true, message: 'Webhook cleanup completed' });
  } catch (error) {
    console.error('Manual webhook cleanup error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Public: Get all funds (for app)
app.get('/api/funds', async (req, res) => {
  try {
    const fundsSnapshot = await db.collection('funds').get();
    const funds = [];
    
    fundsSnapshot.forEach((doc) => {
      const data = doc.data();
      funds.push({ 
        id: doc.id, 
        name: data.name,
        description: data.description,
        imageUrl: data.imageUrl || '',
        walletAddresses: data.walletAddresses || [],
        roi7d: data.roi7d || 0,
        lastUpdated: data.lastUpdated?.toDate?.()?.toISOString() || new Date().toISOString(),
      });
    });

    res.json({ funds });
  } catch (error) {
    console.error('Get funds error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Public: Get single fund details
app.get('/api/funds/:fundId', async (req, res) => {
  try {
    const { fundId } = req.params;
    const fundDoc = await db.collection('funds').doc(fundId).get();
    
    if (!fundDoc.exists) {
      return res.status(404).json({ error: 'Fund not found' });
    }

    const data = fundDoc.data();
    res.json({ 
      id: fundDoc.id,
      name: data.name,
      description: data.description,
      imageUrl: data.imageUrl || '',
      walletAddresses: data.walletAddresses || [],
      roi7d: data.roi7d || 0,
      lastUpdated: data.lastUpdated?.toDate?.()?.toISOString() || new Date().toISOString(),
    });
  } catch (error) {
    console.error('Get fund error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== HELPER FUNCTIONS ====================

// Calculate fund ROI from wallet addresses
async function calculateFundRoi(walletAddresses) {
  const axios = require('axios');
  let totalRoi = 0;
  let successCount = 0;

  for (const walletAddress of walletAddresses) {
    try {
      const response = await axios.get(
        `https://data.solanatracker.io/pnl/${walletAddress}`,
        {
          params: {
            showHistoricPnL: true
          },
          headers: {
            'x-api-key': process.env.SOLANA_TRACKER_API_KEY || '',
          },
          timeout: 15000,
        }
      );
      
      if (response.data && response.data.historic && response.data.historic.summary) {
        // Use 7-day percentage change from historic data
        const sevenDayData = response.data.historic.summary['7d'];
        if (sevenDayData && sevenDayData.percentageChange !== undefined) {
          const roi = sevenDayData.percentageChange;
          totalRoi += roi;
          successCount++;
          console.log(`✅ Fetched ROI for ${walletAddress}: ${roi.toFixed(2)}%`);
        }
      }
    } catch (error) {
      console.error(`❌ Error fetching PNL for wallet ${walletAddress}:`, error.response?.status || error.message);
    }
  }

  return successCount > 0 ? totalRoi / successCount : 0;
}

// Update all funds ROI with historical data using Solana Tracker API
async function updateAllFundsRoi() {
  console.log('🔄 Running ROI update for all funds using Solana Tracker API...');
  const fundsSnapshot = await db.collection('funds').get();

  for (const fundDoc of fundsSnapshot.docs) {
    const fund = fundDoc.data();
    
    if (!fund.walletAddresses || fund.walletAddresses.length === 0) {
      console.log(`⚠️  Fund ${fundDoc.id} has no wallet addresses, skipping...`);
      continue;
    }

    const { roi7d, roiHistory } = await calculateFundRoiFromSolanaTracker(fundDoc.id, fund.walletAddresses);

    // Update fund with new ROI data
    await db.collection('funds').doc(fundDoc.id).update({
      roi7d,
      roiHistory,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Store daily ROI snapshot for historical tracking
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    await db.collection('funds').doc(fundDoc.id).collection('roiSnapshots').doc(today).set({
      roi: roi7d,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      walletCount: fund.walletAddresses.length,
    }, { merge: true });

    console.log(`✅ Updated ROI for fund ${fund.name} (${fundDoc.id}): ${roi7d.toFixed(2)}%`);
    console.log(`   📈 7-Day ROI History: [${roiHistory.map(r => r.toFixed(2)).join(', ')}]`);
  }

  console.log('✅ ROI update completed for all funds');
}

// Helper function to delay execution
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Calculate fund ROI using Solana Tracker API with 7-day history
async function calculateFundRoiFromSolanaTracker(fundId, walletAddresses) {
  try {
    console.log(`\n📊 Calculating ROI from Solana Tracker for fund: ${fundId}`);
    console.log(`   Tracking ${walletAddresses.length} wallets`);

    // Fetch PNL data from Solana Tracker for each wallet
    let totalRoi = 0;
    let successCount = 0;
    const walletRois = [];

    for (let i = 0; i < walletAddresses.length; i++) {
      const walletAddress = walletAddresses[i];
      
      // Add delay between requests to avoid rate limiting (1 second)
      if (i > 0) {
        await delay(1000);
      }
      
      try {
        console.log(`   Fetching PNL for wallet ${i + 1}/${walletAddresses.length}: ${walletAddress.substring(0, 8)}...`);
        
        // Retry logic with exponential backoff
        let retries = 0;
        let maxRetries = 3;
        let response = null;
        
        while (retries < maxRetries) {
          try {
            // Correct API format: /pnl/{wallet} with query params
            response = await axios.get(
              `https://data.solanatracker.io/pnl/${walletAddress}`,
              { 
                params: {
                  period: true,
                  summary: true
                },
                timeout: 15000,
                headers: {
                  'x-api-key': process.env.SOLANA_TRACKER_API_KEY || ''
                }
              }
            );
            break; // Success, exit retry loop
          } catch (err) {
            retries++;
            if (err.response?.status === 429 && retries < maxRetries) {
              const waitTime = Math.pow(2, retries) * 2000; // Exponential backoff: 4s, 8s, 16s
              console.log(`   ⏳ Rate limited, waiting ${waitTime/1000}s before retry ${retries}/${maxRetries}...`);
              await delay(waitTime);
            } else if (err.response?.status === 500 && retries < maxRetries) {
              console.log(`   ⏳ Server error, retrying in 3s (${retries}/${maxRetries})...`);
              await delay(3000);
            } else {
              throw err; // Max retries reached or other error
            }
          }
        }

        // Calculate ROI from PnL data
        if (response && response.data) {
          const summary = response.data.summary || response.data;
          
          // ROI = (total profit / total invested) * 100
          let walletRoi = 0;
          
          if (summary) {
            // Use 7d data if available, otherwise use overall data
            const total = summary['7d']?.total || summary.total || 0;
            const invested = summary['7d']?.totalInvested || summary.totalInvested || 0;
            
            if (invested > 0) {
              walletRoi = (total / invested) * 100;
            } else if (total > 0) {
              // If no investment tracked but has profit, it might be 100% ROI or invalid data
              // For now, skip wallets with no cost basis
              walletRoi = 0;
            }
          }
          
          walletRois.push(walletRoi);
          totalRoi += walletRoi;
          successCount++;
          console.log(`   \u2713 Wallet ROI: ${walletRoi.toFixed(2)}% (invested: $${summary?.totalInvested?.toFixed(2) || 0}, profit: $${summary?.total?.toFixed(2) || 0})`);
        } else {
          console.log(`   ⚠️  Invalid PnL data for wallet`);
          walletRois.push(0);
        }
      } catch (error) {
        const statusCode = error.response?.status || 'unknown';
        console.log(`   ⚠️  Failed to fetch wallet PNL (${statusCode}): ${error.message}`);
        walletRois.push(0);
      }
    }

    // Calculate average ROI across all wallets
    const roi7d = successCount > 0 ? totalRoi / successCount : 0;
    console.log(`   📊 Average Fund ROI: ${roi7d.toFixed(2)}% (${successCount}/${walletAddresses.length} wallets)`);

    // Get historical ROI snapshots from last 7 days
    const roiHistory = await getHistoricalRoiSnapshots(fundId, roi7d);

    return { roi7d, roiHistory };

  } catch (error) {
    console.error(`   ❌ Error calculating ROI from Solana Tracker:`, error.message);
    return { roi7d: 0, roiHistory: [0, 0, 0, 0, 0, 0, 0] };
  }
}

// Get historical ROI snapshots for the last 7 days
async function getHistoricalRoiSnapshots(fundId, currentRoi) {
  try {
    const roiHistory = [];
    const today = new Date();

    // Get snapshots for last 7 days
    for (let i = 6; i >= 0; i--) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      const dayKey = date.toISOString().split('T')[0]; // YYYY-MM-DD

      // Try to get snapshot from database
      const snapshotDoc = await db.collection('funds').doc(fundId)
        .collection('roiSnapshots').doc(dayKey).get();

      if (snapshotDoc.exists) {
        const roi = snapshotDoc.data().roi || 0;
        roiHistory.push(parseFloat(roi.toFixed(2)));
      } else if (i === 0) {
        // For today, use current ROI
        roiHistory.push(parseFloat(currentRoi.toFixed(2)));
      } else {
        // No data for this day, use 0
        roiHistory.push(0);
      }
    }

    return roiHistory;
  } catch (error) {
    console.error(`   ⚠️  Error fetching historical ROI:`, error.message);
    // Return array with current ROI as last value
    return [0, 0, 0, 0, 0, 0, parseFloat(currentRoi.toFixed(2))];
  }
}

// Clean up webhooks for wallets without active investments
async function cleanupWebhooks() {
  if (!process.env.HELIUS_API_KEY) {
    return;
  }

  try {
    console.log('🧹 Cleaning up webhooks for inactive wallets...');
    
    // Get all funds and check which ones have active investments
    const fundsSnapshot = await db.collection('funds').get();
    const activeWallets = new Set();

    for (const fundDoc of fundsSnapshot.docs) {
      const fund = fundDoc.data();
      
      // Check if fund has active investments
      const investmentsSnapshot = await db.collection('investments')
        .where('fundId', '==', fundDoc.id)
        .where('isActive', '==', true)
        .limit(1)
        .get();

      if (!investmentsSnapshot.empty && fund.walletAddresses) {
        fund.walletAddresses.forEach(wallet => activeWallets.add(wallet));
      }
    }

    // Get current webhook
    const listResponse = await axios.get(
      `${HELIUS_WEBHOOK_API}?api-key=${process.env.HELIUS_API_KEY}`
    );
    
    const existingWebhook = listResponse.data.find(
      wh => wh.webhookURL === `${process.env.BACKEND_URL}/api/webhooks/helius`
    );

    if (existingWebhook) {
      const currentAddresses = existingWebhook.accountAddresses || [];
      const filteredAddresses = currentAddresses.filter(addr => activeWallets.has(addr));
      
      // If no active wallets, DELETE the webhook entirely to save credits
      if (filteredAddresses.length === 0) {
        console.log(`   🗑️  Deleting webhook - no active investments`);
        await axios.delete(
          `${HELIUS_WEBHOOK_API}/${existingWebhook.webhookID}?api-key=${process.env.HELIUS_API_KEY}`
        );
        console.log(`✅ Webhook deleted - zero active investments, zero credits used`);
      }
      // If some wallets removed but still have active ones, update the webhook
      else if (filteredAddresses.length < currentAddresses.length) {
        const removed = currentAddresses.length - filteredAddresses.length;
        console.log(`   Removing ${removed} wallets without active investments`);
        
        await axios.put(
          `${HELIUS_WEBHOOK_API}/${existingWebhook.webhookID}?api-key=${process.env.HELIUS_API_KEY}`,
          {
            accountAddresses: filteredAddresses,
            transactionTypes: ['SWAP'],
            webhookType: 'enhanced',
            txnStatus: 'all',
          }
        );
        
        console.log(`✅ Webhook cleaned up: now monitoring ${filteredAddresses.length} active wallets`);
      } else {
        console.log(`   No cleanup needed - all ${currentAddresses.length} wallets have active investments`);
      }
    } else if (activeWallets.size === 0) {
      console.log(`   ✅ No webhook exists and no active investments - zero credits used`);
    }
  } catch (error) {
    console.error('❌ Webhook cleanup error:', error.response?.data || error.message);
  }
}

async function subscribeToWallets(wallets, fundId) {
  if (!process.env.HELIUS_API_KEY) {
    console.log('⚠️  HELIUS_API_KEY not set, skipping webhook subscription');
    return;
  }

  // Check if fund has any active investments before subscribing
  const investmentsSnapshot = await db.collection('investments')
    .where('fundId', '==', fundId)
    .where('isActive', '==', true)
    .limit(1)
    .get();

  if (investmentsSnapshot.empty) {
    console.log(`⏭️  Skipping webhook subscription for fund ${fundId} (no active investments)`);
    return;
  }

  try {
    console.log(`🔔 Subscribing to ${wallets.length} wallets for fund ${fundId} (has active investments)`);
    
    // Check if webhook already exists
    const listResponse = await axios.get(
      `${HELIUS_WEBHOOK_API}?api-key=${process.env.HELIUS_API_KEY}`
    );
    
    const existingWebhook = listResponse.data.find(
      wh => wh.webhookURL === `${process.env.BACKEND_URL}/api/webhooks/helius`
    );

    if (existingWebhook) {
      // Update existing webhook with new addresses
      const existingAddresses = existingWebhook.accountAddresses || [];
      const updatedAddresses = [...new Set([...existingAddresses, ...wallets])];
      
      await axios.put(
        `${HELIUS_WEBHOOK_API}/${existingWebhook.webhookID}?api-key=${process.env.HELIUS_API_KEY}`,
        {
          accountAddresses: updatedAddresses,
          transactionTypes: ['SWAP'],
          webhookType: 'enhanced',
          txnStatus: 'all',
        }
      );
      
      console.log(`✅ Updated existing webhook with ${wallets.length} new addresses`);
    } else {
      // Create new webhook
      const response = await axios.post(
        `${HELIUS_WEBHOOK_API}?api-key=${process.env.HELIUS_API_KEY}`,
        {
          webhookURL: `${process.env.BACKEND_URL}/api/webhooks/helius`,
          transactionTypes: ['SWAP'],
          accountAddresses: wallets,
          webhookType: 'enhanced',
          txnStatus: 'all',
        }
      );
      
      console.log(`✅ Created new Helius webhook: ${response.data.webhookID}`);
    }
  } catch (error) {
    console.error('❌ Helius webhook subscription error:', error.response?.data || error.message);
    // Don't throw - webhook is optional, we have polling fallback
  }
}

async function processTransaction(tx) {
  try {
    const { signature, type, description, source, tokenTransfers, feePayer, accountData } = tx;

    // Check if this is a swap transaction
    if (type !== 'SWAP' && !tokenTransfers) {
      console.log(`⏭️  Skipping non-swap transaction: ${type}`);
      return;
    }

    console.log(`\n🔄 Processing SWAP transaction: ${signature}`);
    console.log(`   Type: ${type}`);
    console.log(`   Description: ${description}`);

    // Extract wallet address - try multiple fields
    let fundWallet = source;
    
    // If source is a protocol name (RAYDIUM, PUMP_AMM, etc), use feePayer or extract from description
    if (source && (source.length < 30 || !source.match(/^[1-9A-HJ-NP-Za-km-z]{32,44}$/))) {
      // Try feePayer first
      if (feePayer) {
        fundWallet = feePayer;
      }
      // Or extract from description (format: "ADDRESS swapped X for Y")
      else if (description) {
        const addressMatch = description.match(/^([1-9A-HJ-NP-Za-km-z]{32,44})\s/);
        if (addressMatch) {
          fundWallet = addressMatch[1];
        }
      }
      // Or check accountData
      else if (accountData && accountData.length > 0) {
        fundWallet = accountData[0].account;
      }
    }

    console.log(`   Fund wallet: ${fundWallet}`);

    // Find ALL funds that use this wallet (multiple funds can share same wallet)
    const matchingFunds = [];
    
    const fundsSnapshot = await db.collection('funds').get();
    for (const fundDoc of fundsSnapshot.docs) {
      const fund = fundDoc.data();
      if (fund.walletAddresses.includes(fundWallet)) {
        matchingFunds.push({ id: fundDoc.id, ...fund });
      }
    }

    if (matchingFunds.length === 0) {
      console.log(`⚠️  No fund found for wallet ${fundWallet}`);
      return;
    }

    console.log(`✅ Found ${matchingFunds.length} fund(s): ${matchingFunds.map(f => f.name).join(', ')}`);

    // Find all investors across ALL matching funds
    let allInvestments = [];
    for (const fund of matchingFunds) {
      const investmentsSnapshot = await db.collection('investments')
        .where('fundId', '==', fund.id)
        .get();
      
      investmentsSnapshot.docs.forEach(doc => {
        allInvestments.push({ doc, fundName: fund.name });
      });
    }

    console.log(`👥 Found ${allInvestments.length} total investors to copy trade`);

    // Execute all copy trades in parallel for instant execution
    const copyTradeTasks = allInvestments.map(async ({ doc: investmentDoc, fundName }) => {
      const investment = investmentDoc.data();
      
      // Skip if investment is disabled
      if (investment.isActive === false) {
        console.log(`   ⏭️  Investment disabled for user ${investment.userId}, skipping`);
        return;
      }
      
      // Skip if auto-approve is disabled
      if (!investment.autoApprove) {
        await sendTradeNotification(investment.userId, tx, investment);
        return;
      }

      // Fast in-memory duplicate check
      const txCacheKey = `${investment.userId}-${investment.fundId}-${signature}`;
      if (processedTransactions.has(txCacheKey)) {
        console.log(`   ⏭️  Transaction ${signature} already processed for user ${investment.userId} (cache hit), skipping`);
        return;
      }
      
      // Mark as processing immediately to prevent race conditions
      processedTransactions.set(txCacheKey, Date.now());

      // Execute copy trade
      await executeCopyTrade(investment, tx, fundWallet, signature);
    });

    // Wait for all copy trades to complete
    await Promise.all(copyTradeTasks);

  } catch (error) {
    console.error('Process transaction error:', error);
  }
}

async function executeCopyTrade(investment, tx, fundWallet, fundTxSignature) {
  const startTime = Date.now();
  let retries = 0;
  
  while (retries < MAX_RETRIES) {
    try {
      const { userId, allocatedAmount, purchaseSizePercentage, fundId } = investment;
      
      // Calculate trade amount based on purchase size percentage
      const tradeAmount = (allocatedAmount * purchaseSizePercentage) / 100;

      console.log(`💰 Executing copy trade for user ${userId} (attempt ${retries + 1}/${MAX_RETRIES})`);
      console.log(`   Trade amount: ${tradeAmount} SOL (${purchaseSizePercentage}% of ${allocatedAmount})`);

      // Get user's encrypted wallet data from Firestore
      const userDoc = await db.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        console.warn(`   ⚠️  User document does not exist for userId: ${userId}, skipping copy trade`);
        return; // Skip this user, don't retry
      }
      
      const userData = userDoc.data();
      
      if (!userData || !userData.encryptedPrivateKey) {
        console.warn(`   ⚠️  User ${userId} has no wallet data (encryptedPrivateKey missing), skipping copy trade`);
        console.warn(`   Available fields:`, Object.keys(userData || {}));
        return; // Skip this user, don't retry
      }

      // Decrypt private key using libsodium
      const privateKeyHex = await decryptData(userData.encryptedPrivateKey);
      const seedBytes = Buffer.from(privateKeyHex, 'hex');
      const userKeypair = Keypair.fromSeed(seedBytes);
      
      console.log(`   User wallet: ${userKeypair.publicKey.toBase58()}`);

      // Check SOL balance before attempting trade
      const balance = await connection.getBalance(userKeypair.publicKey);
      const balanceSOL = balance / 1e9;
      console.log(`   Current SOL balance: ${balanceSOL.toFixed(6)} SOL`);

      // Extract token information from transaction
      if (!tx.tokenTransfers || tx.tokenTransfers.length === 0) {
        throw new Error('No token transfer data in transaction');
      }

      // Find the non-SOL token (the actual token being traded)
      let tokenMint = null;
      let tokenSymbol = 'UNKNOWN';
      let isBuy = false;
      
      for (const transfer of tx.tokenTransfers) {
        if (transfer.mint && transfer.mint !== SOL_MINT) {
          tokenMint = transfer.mint;
          tokenSymbol = transfer.tokenSymbol || 'UNKNOWN';
          // If toUserAccount matches fund wallet, it's a buy (receiving tokens)
          isBuy = transfer.toUserAccount === fundWallet;
          break;
        }
      }
      
      // If no non-SOL token found, this might be a SOL-only transaction (skip it)
      if (!tokenMint) {
        console.log(`   ⚠️  No tradeable token found (SOL-only transaction), skipping`);
        return;
      }
      
      console.log(`   Token: ${tokenSymbol} (${tokenMint})`);
      console.log(`   Type: ${isBuy ? 'BUY' : 'SELL'}`);

      // Determine input/output mints and amounts based on trade type
      let inputMint, outputMintFinal, amountInSmallestUnit;
      
      if (isBuy) {
        // BUY: Use SOL amount from investment
        inputMint = SOL_MINT;
        outputMintFinal = tokenMint;
        amountInSmallestUnit = Math.floor(tradeAmount * 1e9);
        console.log(`   Buy amount: ${tradeAmount} SOL`);
        
        // Validate sufficient balance for BUY trade
        // Need: trade amount + fees (~0.00005 SOL) + token account rent (~0.00203928 SOL if new)
        const requiredBalance = tradeAmount + 0.003; // Extra buffer for fees + rent
        if (balanceSOL < requiredBalance) {
          console.log(`   ❌ Insufficient balance: Need ${requiredBalance.toFixed(6)} SOL, have ${balanceSOL.toFixed(6)} SOL`);
          console.log(`   💡 User needs to top up wallet with at least ${(requiredBalance - balanceSOL).toFixed(6)} SOL`);
          return; // Skip this user
        }
      } else {
        // SELL: Get user's token balance and sell the percentage
        inputMint = tokenMint;
        outputMintFinal = SOL_MINT;
        
        // Validate sufficient SOL for transaction fees (even for SELL)
        const minBalanceForFees = 0.001; // ~0.0005 for tx fee + buffer
        if (balanceSOL < minBalanceForFees) {
          console.log(`   ❌ Insufficient SOL for fees: Need ${minBalanceForFees} SOL for tx fees, have ${balanceSOL.toFixed(6)} SOL`);
          console.log(`   💡 User needs at least ${minBalanceForFees} SOL to pay transaction fees`);
          return; // Skip this user
        }
        
        try {
          // Get user's token account address
          const tokenAccountAddress = await getAssociatedTokenAddress(
            new PublicKey(tokenMint),
            userKeypair.publicKey
          );
          
          // Get token account info
          const tokenAccount = await getAccount(connection, tokenAccountAddress);
          const userTokenBalance = Number(tokenAccount.amount);
          
          // Sell the same percentage as specified in purchaseSizePercentage
          amountInSmallestUnit = Math.floor((userTokenBalance * purchaseSizePercentage) / 100);
          
          console.log(`   User token balance: ${userTokenBalance}`);
          console.log(`   Selling ${purchaseSizePercentage}%: ${amountInSmallestUnit} tokens`);
          
          if (amountInSmallestUnit === 0) {
            console.log(`   ⚠️  User has no tokens to sell, skipping`);
            return;
          }
        } catch (error) {
          console.log(`   ⚠️  User doesn't have this token yet, skipping sell: ${error.message}`);
          return;
        }
      }

      // Add delay to avoid front-running the original trade
      if (COPY_TRADE_DELAY_MS > 0) {
        await new Promise(resolve => setTimeout(resolve, COPY_TRADE_DELAY_MS));
      }

      // Step 1: Get quote from Jupiter
      console.log(`   📊 Getting Jupiter quote...`);
      const quoteResponse = await axios.get(JUPITER_QUOTE_API, {
        params: {
          inputMint,
          outputMint: outputMintFinal,
          amount: amountInSmallestUnit,
          slippageBps: SLIPPAGE_BPS,
        },
        timeout: 3000,
      });

      if (!quoteResponse.data) {
        throw new Error('No quote received from Jupiter');
      }

      const quote = quoteResponse.data;
      console.log(`   💱 Quote received: ${quote.inAmount} → ${quote.outAmount}`);

      // Step 2: Get swap transaction from Jupiter
      console.log(`   🔨 Building swap transaction...`);
      const swapResponse = await axios.post(JUPITER_SWAP_API, {
        quoteResponse: quote,
        userPublicKey: userKeypair.publicKey.toBase58(),
        wrapAndUnwrapSol: true,
        // Use auto priority fee for instant execution
        prioritizationFeeLamports: 'auto',
      }, {
        timeout: 3000,
      });

      if (!swapResponse.data?.swapTransaction) {
        throw new Error('No swap transaction received from Jupiter');
      }

      // Step 3: Deserialize and sign transaction
      console.log(`   ✍️  Signing transaction...`);
      const swapTransactionBuf = Buffer.from(swapResponse.data.swapTransaction, 'base64');
      const transaction = VersionedTransaction.deserialize(swapTransactionBuf);
      transaction.sign([userKeypair]);

      // Step 4: Send transaction to Solana
      console.log(`   📤 Sending transaction to Solana...`);
      const rawTransaction = transaction.serialize();
      const signature = await connection.sendRawTransaction(rawTransaction, {
        skipPreflight: true, // Skip preflight for instant submission
        maxRetries: 3,
        preflightCommitment: 'processed',
      });

      console.log(`   🔗 Transaction sent: ${signature}`);

      // Step 5: Confirm transaction with 'processed' for speed
      console.log(`   ⏳ Confirming transaction...`);
      const confirmation = await connection.confirmTransaction(signature, 'processed');
      
      if (confirmation.value.err) {
        throw new Error(`Transaction failed: ${JSON.stringify(confirmation.value.err)}`);
      }

      const executionTime = Date.now() - startTime;
      console.log(`   ✅ Transaction confirmed in ${executionTime}ms`);

      // Calculate actual amounts from quote
      const actualInputAmount = parseFloat(quote.inAmount) / 1e9;
      const actualOutputAmount = parseFloat(quote.outAmount) / 1e9;
      const price = actualInputAmount / actualOutputAmount;

      // Step 6: Record successful transaction
      const transactionRecord = {
        userId,
        fundId,
        type: isBuy ? 'buy' : 'sell',
        tokenAddress: tokenMint,
        tokenSymbol,
        amount: actualInputAmount,
        outputAmount: actualOutputAmount,
        price,
        totalValue: actualInputAmount,
        signature,
        fundTxSignature,
        timestamp: new Date().toISOString(),
        isSuccess: true,
        errorMessage: null,
        executionTimeMs: executionTime,
        retries: retries,
      };

      await db.collection('transactions').add(transactionRecord);
      
      console.log(`✅ Copy trade executed successfully for user ${userId}`);

      // Send success notification
      await sendSuccessNotification(userId, transactionRecord);

      return; // Success, exit retry loop

    } catch (error) {
      retries++;
      console.error(`❌ Copy trade error (attempt ${retries}/${MAX_RETRIES}):`, error.message);
      
      // Log detailed error for debugging
      if (error.response) {
        console.error(`   API Error Status: ${error.response.status}`);
        console.error(`   API Error Data:`, JSON.stringify(error.response.data, null, 2));
      } else if (error.stack) {
        console.error(`   Stack trace:`, error.stack);
      }
      
      if (retries >= MAX_RETRIES) {
        // Max retries reached, log failed transaction
        console.error(`❌ Max retries reached for user ${investment.userId}`);
        
        await db.collection('transactions').add({
          userId: investment.userId,
          fundId: investment.fundId,
          type: 'buy',
          tokenAddress: tx.tokenTransfers?.[0]?.mint || '',
          tokenSymbol: tx.tokenTransfers?.[0]?.tokenSymbol || 'UNKNOWN',
          amount: 0,
          price: 0,
          totalValue: 0,
          signature: 'failed_' + Date.now(),
          fundTxSignature,
          timestamp: new Date().toISOString(),
          isSuccess: false,
          errorMessage: error.message,
          retries: retries - 1,
        });
        
        // Send failure notification
        await sendFailureNotification(investment.userId, error.message);
      } else {
        // Wait before retry (fast retry for instant execution)
        const waitTime = Math.min(200 * Math.pow(2, retries - 1), 1000); // Faster retries: 200ms, 400ms, 800ms
        console.log(`   ⏳ Waiting ${waitTime}ms before retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
}

async function sendTradeNotification(userId, tx, investment) {
  try {
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData?.fcmToken) {
      console.log(`⚠️  No FCM token for user ${userId}`);
      return;
    }

    const message = {
      notification: {
        title: '🔔 New Trade Detected',
        body: `${tx.description || 'Swap detected'} - Tap to approve`,
      },
      data: {
        type: 'copy_trade',
        transaction: JSON.stringify(tx),
        investmentId: investment.id,
      },
      token: userData.fcmToken,
    };

    await admin.messaging().send(message);
    console.log(`📱 Notification sent to user ${userId}`);
  } catch (error) {
    console.error('Send notification error:', error);
  }
}

async function sendSuccessNotification(userId, transaction) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData?.fcmToken) return;

    const message = {
      notification: {
        title: '✅ Trade Executed',
        body: `${transaction.type.toUpperCase()} ${transaction.tokenSymbol} - ${transaction.amount.toFixed(4)} SOL`,
      },
      data: {
        type: 'trade_success',
        transactionId: transaction.id || '',
        signature: transaction.signature,
      },
      token: userData.fcmToken,
    };

    await admin.messaging().send(message);
  } catch (error) {
    console.error('Send success notification error:', error);
  }
}

async function sendFailureNotification(userId, errorMessage) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData?.fcmToken) return;

    const message = {
      notification: {
        title: '❌ Trade Failed',
        body: `Copy trade failed: ${errorMessage.substring(0, 100)}`,
      },
      data: {
        type: 'trade_failure',
        error: errorMessage,
      },
      token: userData.fcmToken,
    };

    await admin.messaging().send(message);
  } catch (error) {
    console.error('Send failure notification error:', error);
  }
}

// ==================== CRON JOBS ====================

// Update fund ROI every 24 hours at midnight UTC
cron.schedule('0 0 * * *', async () => {
  console.log('🔄 Running scheduled daily ROI update cron job...');
  try {
    await updateAllFundsRoi();
  } catch (error) {
    console.error('ROI update cron error:', error);
  }
});

// Clean up webhooks every 30 minutes to save Helius credits
cron.schedule('*/30 * * * *', async () => {
  console.log('🔄 Running scheduled webhook cleanup cron job...');
  try {
    await cleanupWebhooks();
  } catch (error) {
    console.error('Webhook cleanup cron error:', error);
  }
});

// ==================== START SERVER ====================

const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  console.log(`
  ╔═══════════════════════════════════════╗
  ║  🚀 PumpFunds Backend Server Running  ║
  ╠═══════════════════════════════════════╣
  ║  Port: ${PORT}                          ║
  ║  Environment: ${process.env.NODE_ENV || 'development'}  ║
  ╚═══════════════════════════════════════╝
  `);

  console.log('\n📋 Copy Trading Configuration:');
  console.log(`   Jupiter Quote API: ${JUPITER_QUOTE_API}`);
  console.log(`   Jupiter Swap API: ${JUPITER_SWAP_API}`);
  console.log(`   Slippage BPS: ${SLIPPAGE_BPS} (${SLIPPAGE_BPS/100}%)`);
  console.log(`   Copy Trade Delay: ${COPY_TRADE_DELAY_MS}ms`);
  console.log(`   Max Retries: ${MAX_RETRIES}`);
  console.log(`   Helius API Key: ${process.env.HELIUS_API_KEY ? '✓ Set' : '✗ Not set'}`);
  console.log(`   Backend URL: ${process.env.BACKEND_URL || 'Not set'}\n`);

  // Initialize libsodium encryption
  console.log('🔐 Initializing libsodium encryption...');
  await sodiumEncryption.initialize();
  console.log('✅ Libsodium initialized');

  // Clean up webhooks for inactive wallets on startup
  if (process.env.HELIUS_API_KEY) {
    console.log('🧹 Cleaning up webhooks on startup...');
    await cleanupWebhooks();
  }

  // Start transaction monitor service
  transactionMonitor = new TransactionMonitor(db, processTransaction);
  await transactionMonitor.start();
  
  console.log('✅ All services initialized');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  if (transactionMonitor) {
    transactionMonitor.stop();
  }
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  if (transactionMonitor) {
    transactionMonitor.stop();
  }
  process.exit(0);
});

module.exports = app;
