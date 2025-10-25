import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart';
import 'package:hex/hex.dart';
import '../models/wallet_model.dart';
import 'firebase_service.dart';
import 'sodium_encryption_service.dart';

class WalletService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseService _firebaseService = FirebaseService();
  final SolanaClient _solanaClient = SolanaClient(
    rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
    websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
  );
  
  // Use sodium encryption for guaranteed compatibility with backend
  final SodiumEncryptionService _encryption = SodiumEncryptionService();
  
  // Cache for balance to avoid repeated RPC calls
  double? _cachedBalance;
  DateTime? _balanceCacheTime;
  static const _balanceCacheDuration = Duration(seconds: 10);

  // Keys for secure storage
  static const String _mnemonicKey = 'wallet_mnemonic';
  static const String _privateKeyKey = 'wallet_private_key';
  static const String _addressKey = 'wallet_address';

  /// Encrypt data using libsodium (compatible with backend)
  Future<String> _encryptData(String data) async {
    return await _encryption.encrypt(data);
  }
  
  /// Decrypt data using libsodium (for backend/admin use only)
  Future<String> decryptData(String encryptedData) async {
    return await _encryption.decrypt(encryptedData);
  }

  /// Generate a new Solana wallet with mnemonic and store in Firestore
  Future<Map<String, String>> generateWallet({String? userId}) async {
    try {
      // Generate mnemonic (12 words)
      final mnemonic = bip39.generateMnemonic();
      
      // Derive seed from mnemonic
      final seed = bip39.mnemonicToSeed(mnemonic);
      
      // Derive keypair from seed using ed25519
      final derivedKey = await ED25519_HD_KEY.derivePath("m/44'/501'/0'/0'", seed);
      final privateKey = derivedKey.key;
      
      // Create Solana keypair
      final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);
      final address = keypair.address;

      // Store locally in secure storage
      await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
      await _secureStorage.write(key: _privateKeyKey, value: HEX.encode(privateKey));
      await _secureStorage.write(key: _addressKey, value: address);

      // Encrypt and store in Firestore if userId provided
      if (userId != null) {
        final encryptedPrivateKey = await _encryptData(HEX.encode(privateKey));
        final encryptedMnemonic = await _encryptData(mnemonic);
        
        await _firebaseService.storeUserWalletData(
          userId: userId,
          walletAddress: address,
          encryptedPrivateKey: encryptedPrivateKey,
          encryptedMnemonic: encryptedMnemonic,
        );
      }

      return {
        'address': address,
        'mnemonic': mnemonic,
      };
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  /// Get stored wallet address
  Future<String?> getWalletAddress() async {
    return await _secureStorage.read(key: _addressKey);
  }

  /// Get stored mnemonic
  Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: _mnemonicKey);
  }

  /// Get wallet balance (SOL) with caching
  Future<double> getBalance(String address) async {
    try {
      // Return cached balance if still valid
      if (_cachedBalance != null && 
          _balanceCacheTime != null && 
          DateTime.now().difference(_balanceCacheTime!) < _balanceCacheDuration) {
        return _cachedBalance!;
      }
      
      // Fetch fresh balance
      final balance = await _solanaClient.rpcClient.getBalance(address);
      _cachedBalance = balance.value / 1e9; // Convert lamports to SOL
      _balanceCacheTime = DateTime.now();
      
      return _cachedBalance!;
    } catch (e) {
      // Return cached balance if available, even if expired
      if (_cachedBalance != null) {
        return _cachedBalance!;
      }
      throw Exception('Failed to get balance: $e');
    }
  }

  /// Get USDC balance (SPL token)
  Future<double> getUsdcBalance(String address) async {
    try {
      // TODO: Implement USDC balance check when needed
      // Requires updated Solana package or direct RPC calls
      return 0.0;
    } catch (e) {
      return 0.0; // Return 0 if no USDC account
    }
  }

  /// Get complete wallet info
  Future<WalletModel?> getWalletInfo({bool includePrivateKey = false}) async {
    try {
      final address = await getWalletAddress();
      if (address == null) return null;

      final balance = await getBalance(address);
      final usdcBalance = await getUsdcBalance(address);
      
      String? privateKey;
      if (includePrivateKey) {
        privateKey = await _secureStorage.read(key: _privateKeyKey);
      }

      return WalletModel(
        address: address,
        balance: balance,
        usdcBalance: usdcBalance,
        createdAt: DateTime.now(),
        privateKey: privateKey,
      );
    } catch (e) {
      throw Exception('Failed to get wallet info: $e');
    }
  }

  /// Sign and send transaction
  Future<String> sendTransaction({
    required String recipientAddress,
    required double amount,
  }) async {
    try {
      final privateKeyHex = await _secureStorage.read(key: _privateKeyKey);
      if (privateKeyHex == null) throw Exception('No wallet found');

      final privateKey = Uint8List.fromList(HEX.decode(privateKeyHex));
      final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);

      final lamports = (amount * 1e9).toInt();
      
      final signature = await _solanaClient.transferLamports(
        source: keypair,
        destination: Ed25519HDPublicKey.fromBase58(recipientAddress),
        lamports: lamports,
      );

      return signature;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Build and sign a token swap transaction
  Future<String> executeSwap({
    required String tokenMintAddress,
    required double amount,
    required bool isBuy,
  }) async {
    try {
      final privateKeyHex = await _secureStorage.read(key: _privateKeyKey);
      if (privateKeyHex == null) throw Exception('No wallet found');

      final privateKey = Uint8List.fromList(HEX.decode(privateKeyHex));
      // Note: keypair will be used when implementing actual swap logic
      // final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);

      // TODO: Implement actual swap logic using Jupiter or Raydium
      // This is a placeholder that returns a mock signature
      // In production, integrate with Jupiter Aggregator API or Raydium SDK
      // The keypair will be needed to sign the swap transaction
      
      return 'swap_tx_signature_placeholder_${privateKey.length}';
    } catch (e) {
      throw Exception('Failed to execute swap: $e');
    }
  }

  /// Check if wallet exists
  Future<bool> hasWallet() async {
    final address = await getWalletAddress();
    return address != null;
  }

  /// Clear wallet (logout)
  Future<void> clearWallet() async {
    await _secureStorage.deleteAll();
  }

  /// Import wallet from mnemonic
  Future<String> importWallet(String mnemonic) async {
    try {
      if (!bip39.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      final seed = bip39.mnemonicToSeed(mnemonic);
      final derivedKey = await ED25519_HD_KEY.derivePath("m/44'/501'/0'/0'", seed);
      final privateKey = derivedKey.key;
      
      final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);
      final address = keypair.address;

      await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
      await _secureStorage.write(key: _privateKeyKey, value: HEX.encode(privateKey));
      await _secureStorage.write(key: _addressKey, value: address);

      // Note: keypair used for address derivation
      return address;
    } catch (e) {
      throw Exception('Failed to import wallet: $e');
    }
  }

  /// Sync local wallet to Firestore (for existing wallets that weren't synced)
  Future<void> syncLocalWalletToFirestore(String userId) async {
    try {
      print('🔄 WalletService: Syncing local wallet to Firestore for user: $userId');
      
      final address = await getWalletAddress();
      final privateKeyHex = await _secureStorage.read(key: _privateKeyKey);
      final mnemonic = await getMnemonic();
      
      if (address == null || privateKeyHex == null || mnemonic == null) {
        throw Exception('No local wallet found to sync');
      }
      
      // Encrypt and store in Firestore
      final encryptedPrivateKey = await _encryptData(privateKeyHex);
      final encryptedMnemonic = await _encryptData(mnemonic);
      
      await _firebaseService.storeUserWalletData(
        userId: userId,
        walletAddress: address,
        encryptedPrivateKey: encryptedPrivateKey,
        encryptedMnemonic: encryptedMnemonic,
      );
      
      print('✅ WalletService: Local wallet synced to Firestore successfully');
    } catch (e) {
      print('❌ WalletService: Error syncing wallet: $e');
      throw Exception('Failed to sync wallet to Firestore: $e');
    }
  }

  /// Re-encrypt wallet with backend-compatible encryption (fixes copy trading)
  Future<void> reEncryptWalletForBackend(String userId) async {
    try {
      print('🔐 WalletService: Re-encrypting wallet for backend compatibility...');
      
      // Get the unencrypted private key from secure storage
      final privateKeyHex = await _secureStorage.read(key: _privateKeyKey);
      
      if (privateKeyHex == null || privateKeyHex.isEmpty) {
        print('❌ No private key found in secure storage');
        throw Exception('No private key found');
      }
      
      print('✅ Found private key in secure storage');
      
      // Re-encrypt with sodium (backend-compatible)
      final encryptedPrivateKey = await _encryptData(privateKeyHex);
      
      print('✅ Re-encrypted private key with sodium');
      
      // Update in Firestore
      await _firebaseService.updateUserData(userId, {
        'encryptedPrivateKey': encryptedPrivateKey,
        'encryptionMigrated': true,
        'migratedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ Updated Firestore with backend-compatible encryption');
    } catch (e) {
      print('❌ Wallet re-encryption error: $e');
      throw Exception('Failed to re-encrypt wallet: $e');
    }
  }

  /// Restore wallet from Firestore for existing users
  Future<bool> restoreWalletFromFirestore(String userId) async {
    try {
      print('🔄 WalletService: Starting wallet restoration for user: $userId');
      
      // Check if wallet already exists locally
      final hasLocalWallet = await hasWallet();
      if (hasLocalWallet) {
        print('✅ WalletService: Wallet already exists locally, skipping restore');
        // Skip Firestore sync for faster loading - do it in background if needed
        return true; // Wallet already exists locally
      }

      print('📡 WalletService: Fetching wallet data from Firestore...');
      // Fetch encrypted wallet data from Firestore
      final walletData = await _firebaseService.getUserWalletData(userId);
      if (walletData == null) {
        print('❌ WalletService: No wallet found in Firestore for user: $userId');
        return false; // No wallet found in Firestore
      }

      print('🔍 WalletService: Wallet data retrieved from Firestore');
      final encryptedPrivateKey = walletData['encryptedPrivateKey'] as String?;
      final encryptedMnemonic = walletData['encryptedMnemonic'] as String?;
      final walletAddress = walletData['walletAddress'] as String?;

      print('📝 WalletService: Wallet address: $walletAddress');
      print('📝 WalletService: Has encrypted private key: ${encryptedPrivateKey != null}');
      print('📝 WalletService: Has encrypted mnemonic: ${encryptedMnemonic != null}');

      if (encryptedPrivateKey == null || encryptedMnemonic == null || walletAddress == null) {
        print('❌ WalletService: Incomplete wallet data in Firestore');
        return false; // Incomplete wallet data
      }

      print('🔓 WalletService: Decrypting wallet data...');
      // Decrypt the wallet data
      final privateKeyHex = await decryptData(encryptedPrivateKey);
      final mnemonic = await decryptData(encryptedMnemonic);

      print('💾 WalletService: Storing wallet in local secure storage...');
      // Store in local secure storage
      await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
      await _secureStorage.write(key: _privateKeyKey, value: privateKeyHex);
      await _secureStorage.write(key: _addressKey, value: walletAddress);

      print('✅ WalletService: Wallet successfully restored from Firestore');
      return true;
    } catch (e) {
      print('❌ WalletService: Error restoring wallet: $e');
      throw Exception('Failed to restore wallet from Firestore: $e');
    }
  }
}
