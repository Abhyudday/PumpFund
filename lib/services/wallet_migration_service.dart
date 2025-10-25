import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'firebase_service.dart';

class WalletMigrationService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseService _firebaseService = FirebaseService();
  
  // Use the SAME key as backend
  static const String _encryptionKey = 'pumpfunds_secure_key_32bytes!!@@';
  
  /// Re-encrypt wallet with correct backend-compatible encryption
  Future<bool> migrateWalletEncryption(String userId) async {
    try {
      print('🔄 Starting wallet migration for user: $userId');
      
      // Get the unencrypted private key from secure storage
      final privateKey = await _secureStorage.read(key: 'wallet_private_key');
      
      if (privateKey == null || privateKey.isEmpty) {
        print('❌ No private key found in secure storage');
        return false;
      }
      
      print('✅ Found private key in secure storage');
      
      // Re-encrypt with backend-compatible method
      // CRITICAL: Must match wallet_service.dart encryption exactly
      final key = encrypt.Key.fromUtf8(_encryptionKey); // Use full key
      final iv = encrypt.IV(Uint8List(16)); // All zeros - matches backend
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(privateKey, iv: iv);
      
      print('✅ Re-encrypted private key');
      
      // Update in Firestore
      await _firebaseService.updateUserData(userId, {
        'encryptedPrivateKey': encrypted.base64,
        'encryptionMigrated': true,
        'migratedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ Updated Firestore with new encrypted key');
      
      return true;
    } catch (e) {
      print('❌ Wallet migration error: $e');
      return false;
    }
  }
  
  /// Check if wallet needs migration
  Future<bool> needsMigration(String userId) async {
    try {
      final userData = await _firebaseService.getUserData(userId);
      final migrated = userData?['encryptionMigrated'] as bool?;
      return migrated != true;
    } catch (e) {
      return true; // Assume needs migration if error
    }
  }
}
