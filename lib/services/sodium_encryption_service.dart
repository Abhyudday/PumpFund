import 'dart:convert';
import 'dart:typed_data';
import 'package:sodium_libs/sodium_libs.dart';

/// Encryption service using libsodium for guaranteed compatibility with backend
/// This uses XSalsa20-Poly1305 (secretbox) which is identical in Dart and Node.js
class SodiumEncryptionService {
  // 32-byte key for encryption (must match backend)
  static const String _keyString = 'pumpfunds_secure_key_32bytes!!@@';
  
  late Sodium _sodium;
  late SecureKey _key;
  bool _initialized = false;

  /// Initialize sodium (call once at app startup)
  Future<void> initialize() async {
    if (_initialized) return;
    
    _sodium = await SodiumInit.init();
    
    // Create 32-byte key from string
    final keyBytes = Uint8List(32);
    final sourceBytes = utf8.encode(_keyString);
    final length = sourceBytes.length > 32 ? 32 : sourceBytes.length;
    keyBytes.setRange(0, length, sourceBytes);
    
    _key = SecureKey.fromList(_sodium, keyBytes);
    _initialized = true;
  }

  /// Encrypt data (compatible with Node.js libsodium)
  Future<String> encrypt(String plaintext) async {
    if (!_initialized) await initialize();
    
    final plaintextBytes = utf8.encode(plaintext);
    
    // Generate random nonce (24 bytes for XSalsa20)
    final nonce = _sodium.randombytes.buf(24);
    
    // Encrypt using secretbox
    final ciphertext = _sodium.crypto.secretBox.easy(
      message: Uint8List.fromList(plaintextBytes),
      nonce: nonce,
      key: _key,
    );
    
    // Combine nonce + ciphertext (nonce is not secret)
    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, combined.length, ciphertext);
    
    // Return as base64
    return base64.encode(combined);
  }

  /// Decrypt data (compatible with Node.js libsodium)
  Future<String> decrypt(String encrypted) async {
    if (!_initialized) await initialize();
    
    // Decode from base64
    final combined = base64.decode(encrypted);
    
    // Extract nonce (first 24 bytes) and ciphertext
    final nonce = Uint8List.fromList(combined.sublist(0, 24));
    final ciphertext = Uint8List.fromList(combined.sublist(24));
    
    // Decrypt using secretbox
    final plaintext = _sodium.crypto.secretBox.openEasy(
      cipherText: ciphertext,
      nonce: nonce,
      key: _key,
    );
    
    // Convert back to string
    return utf8.decode(plaintext);
  }

  /// Clean up
  void dispose() {
    if (_initialized) {
      _key.dispose();
      _initialized = false;
    }
  }
}
