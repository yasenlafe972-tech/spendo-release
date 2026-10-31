import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';

/// Elite-grade security service:
/// 1. Hardware-backed Keystore/KeyChain storage via FlutterSecureStorage
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
  enc.IV? _fixedIv;

  /// Initializes cryptographic key material. Generates a secure random 256-bit key
  /// and persists it inside hardware-backed storage if not already present.
  Future<void> initialize() async {
    String? storedKey = await _secureStorage.read(key: _keyMasterSecret);
    if (storedKey == null || storedKey.isEmpty) {
      final key = enc.Key.fromSecureRandom(32);
      storedKey = key.base64;
      await _secureStorage.write(key: _keyMasterSecret, value: storedKey);
    }

    final key = enc.Key.fromBase64(storedKey);
    // 16-byte fixed IV for deterministic searchable columns, or per-record IV
    _fixedIv = enc.IV.fromUtf8('sanad_vault_iv16');
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  /// Encrypts plaintext string to Base64 ciphertext using AES-256
  String encrypt(String plainText) {
    if (_encrypter == null || _fixedIv == null) {
      throw StateError('SecurityService must be initialized before encrypting.');
    }
    if (plainText.isEmpty) return '';
    final encrypted = _encrypter!.encrypt(plainText, iv: _fixedIv);
    return encrypted.base64;
  }

  /// Decrypts Base64 ciphertext back to plaintext using AES-256
  String decrypt(String cipherText) {
    if (_encrypter == null || _fixedIv == null) {
      throw StateError('SecurityService must be initialized before decrypting.');
    }
    if (cipherText.isEmpty) return '';
    try {
      final decrypted = _encrypter!.decrypt64(cipherText, iv: _fixedIv);
      return decrypted;
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
      if (!canAuthenticate) return true; // Fallback if hardware not supported

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
    await _secureStorage.write(key: _keyPinHash, value: hash);
  }

  /// Verify Master PIN
  Future<bool> verifyMasterPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _keyPinHash);
    if (storedHash == null) return true; // No PIN set yet
    final bytes = utf8.encode('sanad_salt_$pin');
    final hash = sha256.convert(bytes).toString();
    return storedHash == hash;
  }

  /// Check if Master PIN is configured
  Future<bool> isPinConfigured() async {
    final storedHash = await _secureStorage.read(key: _keyPinHash);
    return storedHash != null && storedHash.isNotEmpty;
  }
}
