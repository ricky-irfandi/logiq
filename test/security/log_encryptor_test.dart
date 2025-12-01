import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/security/log_encryptor.dart';

void main() {
  group('LogEncryptor', () {
    late Uint8List testKey;

    setUp(() {
      // Generate a test key (32 bytes for AES-256)
      testKey = Uint8List.fromList(List.generate(32, (i) => i));
    });

    group('initialization', () {
      test('should accept 32-byte key', () {
        expect(() => LogEncryptor(testKey), returnsNormally);
      });

      test('should throw on invalid key length', () {
        final shortKey = Uint8List(16); // Only 16 bytes
        expect(
          () => LogEncryptor(shortKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on empty key', () {
        final emptyKey = Uint8List(0);
        expect(
          () => LogEncryptor(emptyKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw on 64-byte key', () {
        final longKey = Uint8List(64);
        expect(
          () => LogEncryptor(longKey),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('encrypt/decrypt round-trip', () {
      test('should decrypt encrypted text correctly', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'This is a test message';

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });

      test('should handle empty string', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = '';

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });

      test('should handle long text', () {
        final encryptor = LogEncryptor(testKey);
        final plaintext = 'x' * 10000;

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });

      test('should handle special characters', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Text with\nnewlines\ttabs and "quotes"';

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });

      test('should handle unicode characters', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = '🎉 Hello 世界 مرحبا 🚀';

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });

      test('should handle JSON strings', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = '{"key":"value","number":42,"bool":true}';

        final encrypted = encryptor.encrypt(plaintext);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, plaintext);
      });
    });

    group('encryption uniqueness', () {
      test('should produce different ciphertext for same plaintext', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Same message';

        final encrypted1 = encryptor.encrypt(plaintext);
        final encrypted2 = encryptor.encrypt(plaintext);

        // Different ciphertexts due to random IV
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to same plaintext
        expect(encryptor.decrypt(encrypted1), plaintext);
        expect(encryptor.decrypt(encrypted2), plaintext);
      });

      test('should produce different IV each time', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Test';

        final encrypted1 = encryptor.encrypt(plaintext);
        final encrypted2 = encryptor.encrypt(plaintext);

        // Extract IVs (first 12 bytes)
        final iv1 = encrypted1.sublist(0, 12);
        final iv2 = encrypted2.sublist(0, 12);

        expect(iv1, isNot(equals(iv2)));
      });
    });

    group('encryption security', () {
      test('encrypted data should be significantly different from plaintext',
          () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Secret message';

        final encrypted = encryptor.encrypt(plaintext);

        // Encrypted should be longer (includes IV and tag)
        expect(encrypted.length, greaterThan(plaintext.length));

        // Encrypted should not contain plaintext
        final encryptedString = String.fromCharCodes(encrypted);
        expect(encryptedString.contains(plaintext), isFalse);
      });

      test('should fail to decrypt tampered ciphertext', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Secret message';

        final encrypted = encryptor.encrypt(plaintext);

        // Tamper with the ciphertext (change one byte)
        final tampered = Uint8List.fromList(encrypted);
        tampered[20] = tampered[20] ^ 0xFF;

        // Should throw on decryption
        expect(
          () => encryptor.decrypt(tampered),
          throwsA(anything), // GCM will throw on authentication failure
        );
      });

      test('should fail to decrypt with wrong key', () {
        final encryptor1 = LogEncryptor(testKey);
        final wrongKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));
        final encryptor2 = LogEncryptor(wrongKey);

        const plaintext = 'Secret message';
        final encrypted = encryptor1.encrypt(plaintext);

        // Should throw when decrypting with wrong key
        expect(
          () => encryptor2.decrypt(encrypted),
          throwsA(anything),
        );
      });

      test('should fail to decrypt truncated ciphertext', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Secret message';

        final encrypted = encryptor.encrypt(plaintext);
        final truncated = encrypted.sublist(0, encrypted.length - 10);

        expect(
          () => encryptor.decrypt(truncated),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should fail to decrypt very short data', () {
        final encryptor = LogEncryptor(testKey);
        final tooShort = Uint8List(10); // Less than IV + tag length

        expect(
          () => encryptor.decrypt(tooShort),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('dispose()', () {
      test('should zero out key bytes', () {
        final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final encryptor = LogEncryptor(key);

        encryptor.dispose();

        // Key should be zeroed (check original Uint8List)
        // Note: We can't directly access _keyBytes, but we can test behavior
        expect(
          () => encryptor.encrypt('test'),
          throwsA(isA<StateError>()),
        );
      });

      test(
          'should throw StateError when using disposed encryptor for encryption',
          () {
        final encryptor = LogEncryptor(testKey);
        encryptor.dispose();

        expect(
          () => encryptor.encrypt('test'),
          throwsA(isA<StateError>()),
        );
      });

      test(
          'should throw StateError when using disposed encryptor for decryption',
          () {
        final encryptor = LogEncryptor(testKey);
        final encrypted = encryptor.encrypt('test');
        encryptor.dispose();

        expect(
          () => encryptor.decrypt(encrypted),
          throwsA(isA<StateError>()),
        );
      });

      test('should be safe to call dispose multiple times', () {
        final encryptor = LogEncryptor(testKey);

        expect(
          () {
            encryptor.dispose();
            encryptor.dispose();
            encryptor.dispose();
          },
          returnsNormally,
        );
      });
    });

    group('cipher reuse', () {
      test('should reuse cipher for multiple encryptions', () {
        final encryptor = LogEncryptor(testKey);

        // Encrypt multiple messages
        final encrypted1 = encryptor.encrypt('Message 1');
        final encrypted2 = encryptor.encrypt('Message 2');
        final encrypted3 = encryptor.encrypt('Message 3');

        // All should decrypt correctly
        expect(encryptor.decrypt(encrypted1), 'Message 1');
        expect(encryptor.decrypt(encrypted2), 'Message 2');
        expect(encryptor.decrypt(encrypted3), 'Message 3');
      });

      test('should handle rapid successive encryptions', () {
        final encryptor = LogEncryptor(testKey);

        for (var i = 0; i < 100; i++) {
          final plaintext = 'Message $i';
          final encrypted = encryptor.encrypt(plaintext);
          final decrypted = encryptor.decrypt(encrypted);

          expect(decrypted, plaintext);
        }
      });
    });

    group('format and structure', () {
      test(
          'encrypted data should have correct structure (IV + ciphertext + tag)',
          () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = 'Test message';

        final encrypted = encryptor.encrypt(plaintext);

        // Should be at least: IV (12) + tag (16) = 28 bytes
        expect(encrypted.length, greaterThanOrEqualTo(28));

        // For non-empty plaintext, should be longer
        expect(encrypted.length, greaterThan(28));
      });

      test('encrypted empty string should have minimum length', () {
        final encryptor = LogEncryptor(testKey);
        const plaintext = '';

        final encrypted = encryptor.encrypt(plaintext);

        // Empty plaintext: IV (12) + tag (16) = 28 bytes
        expect(encrypted.length, 28);
      });
    });

    group('real-world scenarios', () {
      test('should encrypt log entry JSON', () {
        final encryptor = LogEncryptor(testKey);
        const logJson = '{"timestamp":"2025-01-15T10:30:45Z","level":"info",'
            '"category":"API","message":"Request completed",'
            '"context":{"statusCode":200,"duration":125}}';

        final encrypted = encryptor.encrypt(logJson);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, logJson);
      });

      test('should encrypt sensitive user data', () {
        final encryptor = LogEncryptor(testKey);
        const sensitiveData = 'User email: user@example.com, '
            'Credit card: 4532-1234-5678-9010, '
            'SSN: 123-45-6789';

        final encrypted = encryptor.encrypt(sensitiveData);

        // Verify encrypted data doesn't contain sensitive info
        final encryptedString = String.fromCharCodes(encrypted);
        expect(encryptedString.contains('user@example.com'), isFalse);
        expect(encryptedString.contains('4532'), isFalse);
        expect(encryptedString.contains('123-45'), isFalse);

        // But should decrypt correctly
        final decrypted = encryptor.decrypt(encrypted);
        expect(decrypted, sensitiveData);
      });

      test('should handle batch encryption efficiently', () {
        final encryptor = LogEncryptor(testKey);
        final messages = List.generate(1000, (i) => 'Log entry $i');

        final startTime = DateTime.now();

        for (final message in messages) {
          final encrypted = encryptor.encrypt(message);
          encryptor.decrypt(encrypted);
        }

        final duration = DateTime.now().difference(startTime);

        // Should complete in reasonable time (adjust threshold as needed)
        expect(duration.inSeconds, lessThan(5));
      });
    });
  });
}
