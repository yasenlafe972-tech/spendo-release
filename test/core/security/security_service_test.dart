import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/security/security_service.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService Encryption & Decryption Tests', () {
    test('Encrypt with dynamic random IV produces different ciphertexts for same input', () {
      final security = SecurityService.instance;
      const plainText = 'MySuperSecretPassword#2026';

      final cipher1 = security.encrypt(plainText);
      final cipher2 = security.encrypt(plainText);

      // Must produce different ciphertexts due to dynamic random IV
      expect(cipher1 != cipher2, isTrue);

      // Must follow the ivBase64:cipherBase64 format
      expect(cipher1.contains(':'), isTrue);
      expect(cipher2.contains(':'), isTrue);

      final parts1 = cipher1.split(':');
      final parts2 = cipher2.split(':');
      expect(parts1.length, 2);
      expect(parts2.length, 2);
      expect(parts1[0] != parts2[0], isTrue); // IVs are distinct

      // Both must decrypt back to the original plaintext
      expect(security.decrypt(cipher1), plainText);
      expect(security.decrypt(cipher2), plainText);
    });

    test('Backward compatibility: decrypts legacy ciphertexts with fixed IV', () {
      final security = SecurityService.instance;

      // Legacy encryption produced before dynamic IV was introduced
      final fallbackKey = enc.Key.fromUtf8('sanad_default_master_key_32bytes');
      final fixedIv = enc.IV.fromUtf8('sanad_vault_iv16');
      final legacyEncrypter = enc.Encrypter(enc.AES(fallbackKey, mode: enc.AESMode.cbc));
      final legacyCipher = legacyEncrypter.encrypt('OldLegacySecret123', iv: fixedIv).base64;

      // Ensure it contains no colon and was produced using legacy fixed IV
      expect(legacyCipher.contains(':'), isFalse);

      final decrypted = security.decrypt(legacyCipher);
      expect(decrypted, 'OldLegacySecret123');
    });

    test('Empty string returns empty string', () {
      final security = SecurityService.instance;
      expect(security.encrypt(''), '');
      expect(security.decrypt(''), '');
    });

    test('Non-ciphertext gracefully returns raw string', () {
      final security = SecurityService.instance;
      const rawText = 'JustAPlainTextString';
      expect(security.decrypt(rawText), rawText);
    });
  });
}
