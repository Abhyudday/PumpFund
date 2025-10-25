const sodium = require('libsodium-wrappers');

const KEY_STRING = 'pumpfunds_secure_key_32bytes!!@@';

// Initialize sodium
let initialized = false;
let key = null;

async function initialize() {
  if (initialized) return;
  
  await sodium.ready;
  
  // Create 32-byte key from string (same as Flutter)
  const keyBytes = new Uint8Array(32);
  const sourceBytes = Buffer.from(KEY_STRING, 'utf8');
  const length = Math.min(sourceBytes.length, 32);
  keyBytes.set(sourceBytes.slice(0, length), 0);
  
  key = keyBytes;
  initialized = true;
}

/**
 * Encrypt data using libsodium secretbox (XSalsa20-Poly1305)
 * Compatible with Flutter sodium_libs
 */
async function encryptData(plaintext) {
  if (!initialized) await initialize();
  
  const plaintextBytes = Buffer.from(plaintext, 'utf8');
  
  // Generate random nonce (24 bytes for XSalsa20)
  const nonce = sodium.randombytes_buf(24);
  
  // Encrypt using secretbox
  const ciphertext = sodium.crypto_secretbox_easy(plaintextBytes, nonce, key);
  
  // Combine nonce + ciphertext
  const combined = new Uint8Array(nonce.length + ciphertext.length);
  combined.set(nonce, 0);
  combined.set(ciphertext, nonce.length);
  
  // Return as base64
  return Buffer.from(combined).toString('base64');
}

/**
 * Decrypt data using libsodium secretbox
 * Compatible with Flutter sodium_libs
 */
async function decryptData(encrypted) {
  if (!initialized) await initialize();
  
  // Decode from base64
  const combined = Buffer.from(encrypted, 'base64');
  
  // Extract nonce (first 24 bytes) and ciphertext
  const nonce = combined.slice(0, 24);
  const ciphertext = combined.slice(24);
  
  // Decrypt using secretbox
  const plaintext = sodium.crypto_secretbox_open_easy(ciphertext, nonce, key);
  
  // Convert back to string
  return Buffer.from(plaintext).toString('utf8');
}

module.exports = {
  initialize,
  encryptData,
  decryptData
};
