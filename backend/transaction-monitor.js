const axios = require('axios');
const admin = require('firebase-admin');

/**
 * Transaction Monitor Service
 * Polls Helius API for fund wallet transactions as a fallback to webhooks
 * Ensures copy trading works even if webhooks fail
 */

class TransactionMonitor {
  constructor(db, processTransactionCallback) {
    this.db = db;
    this.processTransaction = processTransactionCallback;
    this.monitoredWallets = new Map(); // wallet -> fundId mapping
    this.lastCheckedSignatures = new Map(); // wallet -> last signature
    this.processedSignatures = new Set(); // Track processed signatures to prevent duplicates
    this.isRunning = false;
    this.pollInterval = 5000; // 5 seconds - reduced from 100ms to save API credits
    this.heliusApiKey = process.env.HELIUS_API_KEY;
    this.lastPollTime = new Map(); // Track last poll time per wallet
    this.minPollInterval = 3000; // Minimum 3 seconds between polls per wallet
    
    // Clear old signatures every 10 minutes to prevent memory leak
    setInterval(() => {
      if (this.processedSignatures.size > 1000) {
        console.log('🧹 Cleaning old processed signatures cache');
        this.processedSignatures.clear();
      }
    }, 600000);
  }

  async start() {
    if (this.isRunning) {
      console.log('⚠️  Transaction monitor already running');
      return;
    }

    console.log('🚀 Starting transaction monitor service...');
    this.isRunning = true;

    // Load all fund wallets
    await this.loadFundWallets();

    // Refresh monitored wallets every 5 minutes to adapt to investment changes
    setInterval(() => {
      this.loadFundWallets();
    }, 300000); // 5 minutes

    // Start polling loop
    this.poll();
  }

  stop() {
    console.log('🛑 Stopping transaction monitor service...');
    this.isRunning = false;
  }

  async loadFundWallets() {
    try {
      // Only load wallets that have active investments
      const fundsSnapshot = await this.db.collection('funds').get();
      const walletsToMonitor = new Set();
      
      for (const fundDoc of fundsSnapshot.docs) {
        const fund = fundDoc.data();
        if (!fund.walletAddresses || fund.walletAddresses.length === 0) {
          continue;
        }

        // Check if this fund has any active investments
        const investmentsSnapshot = await this.db.collection('investments')
          .where('fundId', '==', fundDoc.id)
          .where('isActive', '==', true)
          .limit(1)
          .get();

        // Only monitor if there are active investments
        if (!investmentsSnapshot.empty) {
          fund.walletAddresses.forEach(wallet => {
            this.monitoredWallets.set(wallet, fundDoc.id);
            walletsToMonitor.add(wallet);
            console.log(`📍 Monitoring wallet ${wallet} for fund ${fund.name} (has active investments)`);
          });
        } else {
          console.log(`⏭️  Skipping fund ${fund.name} (no active investments)`);
        }
      }

      if (this.monitoredWallets.size === 0) {
        console.log(`✅ Zero wallets to monitor - no active investments found`);
        console.log(`   💰 Helius API usage: ZERO credits (no polling when no active investments)`);
      } else {
        console.log(`✅ Loaded ${this.monitoredWallets.size} wallets to monitor (only with active investments)`);
      }
    } catch (error) {
      console.error('❌ Error loading fund wallets:', error);
    }
  }

  async poll() {
    if (!this.isRunning) return;

    try {
      await this.checkAllWallets();
    } catch (error) {
      console.error('❌ Polling error:', error.message);
    }

    // Schedule next poll
    setTimeout(() => this.poll(), this.pollInterval);
  }

  async checkAllWallets() {
    const wallets = Array.from(this.monitoredWallets.keys());
    
    if (wallets.length === 0) {
      return;
    }

    // Filter wallets that need checking based on minimum interval
    const now = Date.now();
    const walletsToCheck = wallets.filter(wallet => {
      const lastPoll = this.lastPollTime.get(wallet) || 0;
      return (now - lastPoll) >= this.minPollInterval;
    });

    if (walletsToCheck.length === 0) {
      return;
    }

    // Process in batches of 5 to avoid rate limits
    const batchSize = 5;
    for (let i = 0; i < walletsToCheck.length; i += batchSize) {
      const batch = walletsToCheck.slice(i, i + batchSize);
      await Promise.all(batch.map(wallet => this.checkWallet(wallet)));
      
      // Small delay between batches to avoid rate limits
      if (i + batchSize < walletsToCheck.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
  }

  async checkWallet(walletAddress) {
    try {
      // Update last poll time
      this.lastPollTime.set(walletAddress, Date.now());

      if (!this.heliusApiKey) {
        // Fallback to public RPC (limited)
        return await this.checkWalletPublicRPC(walletAddress);
      }

      // Use Helius enhanced API - only check last 3 transactions to save credits
      const response = await axios.get(
        `https://api.helius.xyz/v0/addresses/${walletAddress}/transactions?api-key=${this.heliusApiKey}`,
        {
          params: {
            limit: 3, // Reduced from 10 to 3 to save API credits
            type: 'SWAP',
          },
          timeout: 3000
        }
      );

      const transactions = response.data;
      
      if (!transactions || transactions.length === 0) {
        return;
      }

      // Get last checked signature for this wallet
      const lastSignature = this.lastCheckedSignatures.get(walletAddress);
      
      // Process new transactions
      for (const tx of transactions) {
        // Stop if we've reached previously processed transactions
        if (tx.signature === lastSignature) {
          break;
        }

        // Skip if already processed
        if (this.processedSignatures.has(tx.signature)) {
          continue;
        }

        // Only process SWAP transactions
        if (tx.type === 'SWAP') {
          console.log(`🔍 New transaction detected: ${tx.signature}`);
          this.processedSignatures.add(tx.signature);
          await this.processTransaction(tx);
        }
      }

      // Update last checked signature
      if (transactions.length > 0) {
        this.lastCheckedSignatures.set(walletAddress, transactions[0].signature);
      }

    } catch (error) {
      // Don't log every error to avoid spam
      if (error.response?.status !== 429) {
        console.error(`Error checking wallet ${walletAddress}:`, error.message);
      }
    }
  }

  async checkWalletPublicRPC(walletAddress) {
    try {
      const connection = new (require('@solana/web3.js').Connection)(
        process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com'
      );

      const signatures = await connection.getSignaturesForAddress(
        new (require('@solana/web3.js').PublicKey)(walletAddress),
        { limit: 5 }
      );

      const lastSignature = this.lastCheckedSignatures.get(walletAddress);

      for (const sigInfo of signatures) {
        if (sigInfo.signature === lastSignature) {
          break;
        }

        // Skip if already processed
        if (this.processedSignatures.has(sigInfo.signature)) {
          continue;
        }

        // Fetch full transaction details
        const tx = await connection.getParsedTransaction(sigInfo.signature, {
          maxSupportedTransactionVersion: 0,
        });

        if (tx && this.isSwapTransaction(tx)) {
          // Convert to Helius-like format
          const enhancedTx = this.convertToHeliusFormat(tx, walletAddress);
          console.log(`🔍 New transaction detected: ${sigInfo.signature}`);
          this.processedSignatures.add(sigInfo.signature);
          await this.processTransaction(enhancedTx);
        }
      }

      if (signatures.length > 0) {
        this.lastCheckedSignatures.set(walletAddress, signatures[0].signature);
      }

    } catch (error) {
      console.error(`Error checking wallet ${walletAddress} (public RPC):`, error.message);
    }
  }

  isSwapTransaction(tx) {
    // Check if transaction contains token transfers (indicates a swap)
    const meta = tx.meta;
    if (!meta || !meta.postTokenBalances || !meta.preTokenBalances) {
      return false;
    }

    // A swap typically has both pre and post token balances
    return meta.postTokenBalances.length > 0 && meta.preTokenBalances.length > 0;
  }

  convertToHeliusFormat(tx, walletAddress) {
    // Convert Solana transaction to Helius-like format
    const meta = tx.meta;
    const tokenTransfers = [];

    // Extract token transfers from balance changes
    if (meta.postTokenBalances && meta.preTokenBalances) {
      for (const postBalance of meta.postTokenBalances) {
        const preBalance = meta.preTokenBalances.find(
          pre => pre.accountIndex === postBalance.accountIndex
        );

        if (preBalance) {
          const change = postBalance.uiTokenAmount.uiAmount - preBalance.uiTokenAmount.uiAmount;
          if (change !== 0) {
            tokenTransfers.push({
              mint: postBalance.mint,
              tokenSymbol: postBalance.uiTokenAmount.symbol || 'UNKNOWN',
              fromUserAccount: change < 0 ? walletAddress : null,
              toUserAccount: change > 0 ? walletAddress : null,
              amount: Math.abs(change),
            });
          }
        }
      }
    }

    return {
      signature: tx.transaction.signatures[0],
      type: 'SWAP',
      description: 'Token swap detected',
      source: walletAddress,
      tokenTransfers,
      timestamp: tx.blockTime,
    };
  }

  async addWallet(walletAddress, fundId) {
    this.monitoredWallets.set(walletAddress, fundId);
    console.log(`📍 Added wallet ${walletAddress} to monitor for fund ${fundId}`);
  }

  async removeWallet(walletAddress) {
    this.monitoredWallets.delete(walletAddress);
    this.lastCheckedSignatures.delete(walletAddress);
    console.log(`🗑️  Removed wallet ${walletAddress} from monitoring`);
  }
}

module.exports = TransactionMonitor;
