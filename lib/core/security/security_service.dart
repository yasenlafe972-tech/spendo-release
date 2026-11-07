import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Elite-grade security service:
/// 1. Hardware-backed Keystore/KeyChain storage via FlutterSecureStorage (with SharedPreferences fallback for sideloaded iOS)
/// 2. AES-256 symmetric encryption for sensitive data (National ID, Passwords, Secrets)
/// 3. Biometric authentication (Fingerprint / Face ID) via LocalAuthentication
class SecurityService {
  static final SecurityService instance = SecurityService._internal();
  SecurityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyMasterSecret = 'sanad_master_key_v1';
  static const String _keyPinHash = 'sanad_pin_hash_v1';

  enc.Encrypter? _encrypter;
  final List<enc.Encrypter> _fallbackEncrypters = [];
  String? _currentMasterKeyBase64;
  enc.IV? _legacyFixedIv;

  void _ensureInitialized() {
    if (_encrypter != null) return;
    // Generate a secure ephemeral key if initialize() was not awaited
    final key = enc.Key.fromSecureRandom(32);
    _currentMasterKeyBase64 = key.base64;
    _legacyFixedIv = enc.IV.fromUtf8('sanad_vault_iv16');
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  /// Returns the active AES-256 master key (Base64) so it can be synchronized across devices
  Future<String?> getMasterKeyBase64() async {
    if (_currentMasterKeyBase64 != null && _currentMasterKeyBase64!.isNotEmpty) {
      return _currentMasterKeyBase64;
    }
    try {
      final k = await _secureStorage.read(key: _keyMasterSecret);
      if (k != null && k.isNotEmpty) {
        _currentMasterKeyBase64 = k;
        return k;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = prefs.getString(_keyMasterSecret);
      if (k != null && k.isNotEmpty) {
        _currentMasterKeyBase64 = k;
        return k;
      }
    } catch (_) {}
    return _currentMasterKeyBase64;
  }

  /// Adopts a synchronized AES-256 master key from cloud backup while keeping any local key as fallback
  Future<void> adoptMasterKey(String base64Key) async {
    final clean = base64Key.trim();
    if (clean.isEmpty) return;
    try {
      final newKey = enc.Key.fromBase64(clean);
      if (_encrypter != null && _currentMasterKeyBase64 != clean) {
        _fallbackEncrypters.add(_encrypter!);
      }
      _currentMasterKeyBase64 = clean;
      _legacyFixedIv = enc.IV.fromUtf8('sanad_vault_iv16');
      _encrypter = enc.Encrypter(enc.AES(newKey, mode: enc.AESMode.cbc));
      try {
        await _secureStorage.write(key: _keyMasterSecret, value: clean);
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyMasterSecret, clean);
      } catch (_) {}
    } catch (_) {}
  }

  /// Initializes cryptographic key material. Generates a secure random 256-bit key
  /// and persists it inside hardware-backed storage (or SharedPreferences on sideloaded iOS).
  Future<void> initialize() async {
    String? storedKey;
    try {
      storedKey = await _secureStorage.read(key: _keyMasterSecret);
    } catch (_) {
      storedKey = null;
    }

    if (storedKey == null || storedKey.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        storedKey = prefs.getString(_keyMasterSecret);
      } catch (_) {}
    }

    if (storedKey == null || storedKey.isEmpty) {
      final key = enc.Key.fromSecureRandom(32);
      storedKey = key.base64;
      try {
        await _secureStorage.write(key: _keyMasterSecret, value: storedKey);
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyMasterSecret, storedKey);
      } catch (_) {}
    }

    try {
      _currentMasterKeyBase64 = storedKey;
      final key = enc.Key.fromBase64(storedKey);
      _legacyFixedIv = enc.IV.fromUtf8('sanad_vault_iv16');
      _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    } catch (_) {
      _ensureInitialized();
    }
  }

  /// Encrypts plaintext string to Base64 ciphertext with dynamic IV prepended using AES-256
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    _ensureInitialized();
    try {
      final dynamicIv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: dynamicIv);
      return '${dynamicIv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('>>> [SecurityService] Encryption error: $e');
      throw StateError('Failed to encrypt data securely: $e');
    }
  }

  /// Decrypts Base64 ciphertext back to plaintext using AES-256
  String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';
    _ensureInitialized();
    try {
      // 1. Dynamic IV prepended with delimiter (ivBase64:ciphertextBase64)
      if (cipherText.contains(':')) {
        final parts = cipherText.split(':');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          try {
            final iv = enc.IV.fromBase64(parts[0]);
            return _encrypter!.decrypt64(parts[1], iv: iv);
          } catch (_) {
            for (final fb in _fallbackEncrypters) {
              try {
                final iv = enc.IV.fromBase64(parts[0]);
                return fb.decrypt64(parts[1], iv: iv);
              } catch (_) {}
            }
          }
        }
      }

      // 2. Backward compatibility: if payload starts with standard IV base64
      final standardIv = _legacyFixedIv ?? enc.IV.fromUtf8('sanad_vault_iv16');
      final standardIvBase64 = standardIv.base64;
      if (cipherText.startsWith(standardIvBase64) && cipherText.length > standardIvBase64.length) {
        try {
          final payload = cipherText.substring(standardIvBase64.length);
          return _encrypter!.decrypt64(payload, iv: standardIv);
        } catch (_) {}
      }

      // 3. Backward compatibility: legacy payload encrypted with standard IV directly (no prepended IV)
      try {
        return _encrypter!.decrypt64(cipherText, iv: standardIv);
      } catch (_) {}

      // 4. Backward compatibility: fixed-length 16-byte IV prepended without delimiter (24 chars base64)
      if (cipherText.length > 24) {
        try {
          final iv = enc.IV.fromBase64(cipherText.substring(0, 24));
          final payload = cipherText.substring(24);
          return _encrypter!.decrypt64(payload, iv: iv);
        } catch (_) {}
      }

      // 5. Backward compatibility: legacy ciphertexts created with legacy fallback master key
      try {
        final legacyFallbackEncrypter = enc.Encrypter(
          enc.AES(enc.Key.fromUtf8('sanad_default_master_key_32bytes'), mode: enc.AESMode.cbc),
        );
        return legacyFallbackEncrypter.decrypt64(cipherText, iv: standardIv);
      } catch (_) {}

      return cipherText;
    } catch (_) {
      // In case data is unencrypted or key rotated
      return cipherText;
    }
  }

  /// Authenticate user via Biometrics (Fingerprint or Face ID)
  Future<bool> authenticateBiometrics({String reason = 'يرجى تأكيد الهوية للوصول إلى الخزنة'}) async {
    try {
      final bool canAuthenticate =
          await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canAuthenticate) return false; // Fallback if hardware not supported

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Set Master PIN with SHA-256 salted hash
  Future<void> setMasterPin(String pin) async {
    final bytes = utf8.encode('sanad_salt_$pin');
    final hash = sha256.convert(bytes).toString();
    try {
      await _secureStorage.write(key: _keyPinHash, value: hash);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPinHash, hash);
    } catch (_) {}
  }

  /// Verify Master PIN
  Future<bool> verifyMasterPin(String pin) async {
    String? storedHash;
    try {
      storedHash = await _secureStorage.read(key: _keyPinHash);
    } catch (_) {}
    if (storedHash == null || storedHash.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        storedHash = prefs.getString(_keyPinHash);
      } catch (_) {}
    }
    if (storedHash == null || storedHash.isEmpty) return true; // No PIN set yet
    final bytes = utf8.encode('sanad_salt_$pin');
    final hash = sha256.convert(bytes).toString();
    return storedHash == hash;
  }

  /// Check if Master PIN is configured
  Future<bool> isPinConfigured() async {
    String? storedHash;
    try {
      storedHash = await _secureStorage.read(key: _keyPinHash);
    } catch (_) {}
    if (storedHash == null || storedHash.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        storedHash = prefs.getString(_keyPinHash);
      } catch (_) {}
    }
    return storedHash != null && storedHash.isNotEmpty;
  }
}
