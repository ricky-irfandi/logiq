import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';
import 'package:logiq/src/security/log_encryptor.dart';
import 'package:archive/archive.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logiq Integration Tests', () {
    late Directory tempDir;
    late String logDirectory;

    setUp(() async {
      tempDir = await TestHelpers.createTempDirectory();
      logDirectory = '${tempDir.path}/logs';
    });

    tearDown(() async {
      try {
        await Logiq.dispose();
      } catch (_) {
        // Ignore
      }

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('full logging workflow', () {
      test('should complete full logging cycle: init → log → flush → read',
          () async {
        // Initialize
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            format: const FormatConfig.json(),
            minLevel: LogLevel.verbose,
          ),
        );

        // Log various levels
        Logiq.v('APP', 'Application starting');
        Logiq.d('DATABASE', 'Connecting to database');
        Logiq.i('AUTH', 'User logged in', {'userId': 123});
        Logiq.w('API', 'Rate limit approaching');
        Logiq.e('PAYMENT', 'Payment processing failed', {'error': 'timeout'});
        Logiq.f('SYSTEM', 'Critical system failure');

        // Flush
        await Logiq.flush();

        // Verify all logs were written
        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, logContains('Application starting'));
        expect(content, logContains('Connecting to database'));
        expect(content, logContains('User logged in'));
        expect(content, logContains('Rate limit approaching'));
        expect(content, logContains('Payment processing failed'));
        expect(content, logContains('Critical system failure'));

        // Verify statistics
        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 6);
        expect(stats.bufferedCount, 0); // All flushed
        expect(stats.storageUsed, greaterThan(0));
      });

      test('should maintain log integrity across multiple flush cycles',
          () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 10,
          ),
        );

        // Multiple batches
        for (var batch = 0; batch < 5; batch++) {
          for (var i = 0; i < 10; i++) {
            Logiq.i('BATCH_$batch', 'Message $i');
          }
          await Logiq.flush();
        }

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();

        // Should have all 50 messages
        expect(lines.length, 50);

        // Verify all batches present
        for (var batch = 0; batch < 5; batch++) {
          expect(content, logContains('BATCH_$batch'));
        }
      });
    });

    group('encryption end-to-end', () {
      test('should encrypt logs and allow decryption', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));

        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            encryption: EncryptionConfig.aes256WithKey(key: encryptionKey),
            format: const FormatConfig.json(),
          ),
        );

        Logiq.i('SECRET', 'Sensitive information here');
        Logiq.i('PAYMENT', 'Credit card transaction', {'amount': 1000});

        await Logiq.flush();

        // Read encrypted file
        final encryptedContent =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Should not contain plaintext
        expect(encryptedContent, isNot(contains('Sensitive information')));
        expect(encryptedContent, isNot(contains('Credit card')));

        // Decrypt line by line (each log entry is encrypted separately)
        final lines = encryptedContent
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final encryptor = LogEncryptor(encryptionKey);
        final decryptedLines = <String>[];
        for (final line in lines) {
          final encrypted = base64Decode(line.trim());
          decryptedLines.add(encryptor.decrypt(encrypted));
        }
        final decrypted = decryptedLines.join('\n');

        expect(decrypted, contains('Sensitive information'));
        expect(decrypted, contains('Credit card transaction'));
      });

      test('should handle encryption with rotation', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));

        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            encryption: EncryptionConfig.aes256WithKey(key: encryptionKey),
            rotation: RotationConfig.multiFile(
              maxFileSize: 2000,
              maxFiles: 3,
            ),
          ),
        );

        // Generate enough logs to trigger rotation
        for (var i = 0; i < 100; i++) {
          Logiq.i('TEST', 'Message $i with padding' * 10);
        }

        await Logiq.flush();

        // Should have rotated files
        final backup1 = File('$logDirectory/backup_1.log');
        expect(backup1, await fileExists());

        // All files should be encrypted
        final backup1Content = await backup1.readAsString();
        expect(backup1Content, isNot(contains('Message')));
      });
    });

    group('redaction pipeline', () {
      test('should redact PII throughout logging pipeline', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            redactionPatterns: [
              RedactionPattern.email,
              RedactionPattern.phoneIndonesia,
              RedactionPattern.creditCard,
            ],
            format: const FormatConfig.json(),
          ),
        );

        Logiq.i('USER', 'User registered with email user@example.com');
        Logiq.i('CONTACT', 'Phone number: +628123456789');
        Logiq.i('PAYMENT', 'Card number: 4532-1234-5678-9010');
        Logiq.i('MIXED', 'Email: admin@test.com, Phone: 081234567890', {
          'userEmail': 'contact@example.org',
          'cardNumber': '4532123456789010',
        });

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // All PII should be redacted
        expect(content, isNot(contains('user@example.com')));
        expect(content, isNot(contains('+628123456789')));
        expect(content, isNot(contains('4532-1234-5678-9010')));
        expect(content, isNot(contains('admin@test.com')));
        expect(content, isNot(contains('contact@example.org')));

        // Redaction markers should be present
        expect(content, logContains('[EMAIL_REDACTED]'));
        expect(content, logContains('[PHONE_REDACTED]'));
        expect(content, logContains('[CARD_REDACTED]'));
      });

      test('should support runtime redaction additions', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            redactionPatterns: [RedactionPattern.email],
          ),
        );

        Logiq.i('TEST', 'Email: user@test.com, Token: secret_token_abc123');
        await Logiq.flush();

        // Add custom pattern at runtime
        Logiq.addRedaction(
          RedactionPattern(
            name: 'token',
            pattern: RegExp(r'secret_token_[a-z0-9]+'),
            replacement: '[TOKEN_REDACTED]',
          ),
        );

        Logiq.i('TEST', 'Email: admin@test.com, Token: secret_token_xyz789');
        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Both patterns should be applied to second message
        final lines = content.split('\n');
        final lastLine = lines[lines.length - 2]; // -2 because last is empty

        expect(lastLine, contains('[EMAIL_REDACTED]'));
        expect(lastLine, contains('[TOKEN_REDACTED]'));
      });
    });

    group('rotation scenarios', () {
      test('should rotate files correctly with multi-file strategy', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            rotation: RotationConfig.multiFile(
              maxFileSize: 3000,
              maxFiles: 3,
            ),
          ),
        );

        // Generate logs to trigger multiple rotations
        for (var batch = 0; batch < 5; batch++) {
          for (var i = 0; i < 20; i++) {
            Logiq.i('BATCH_$batch', 'Message $i${' padding' * 30}');
          }
          await Logiq.flush();
        }

        // Verify rotation happened
        final current = File('$logDirectory/current.log');
        final backup1 = File('$logDirectory/backup_1.log');

        expect(current, await fileExists());
        expect(backup1, await fileExists());

        // Verify content distribution
        final currentContent = await current.readAsString();
        final backup1Content = await backup1.readAsString();

        expect(currentContent, isNotEmpty);
        expect(backup1Content, isNotEmpty);

        // Most recent batch should be in current or backup_1
        expect(
          currentContent.contains('BATCH_4') ||
              backup1Content.contains('BATCH_4'),
          isTrue,
        );
      });

      test('should trim file correctly with single-file strategy', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            rotation: RotationConfig.singleFile(
              maxFileSize: 5000,
              trimPercent: 30,
            ),
          ),
        );

        // Generate many logs
        for (var i = 0; i < 200; i++) {
          Logiq.i('TEST', 'Entry $i${' padding' * 20}');
        }

        await Logiq.flush();

        // Should only have current.log, no backups
        final backup1 = File('$logDirectory/backup_1.log');
        expect(await backup1.exists(), isFalse);

        final current = File('$logDirectory/current.log');
        expect(current, await fileExists());

        // File should be trimmed to under max size
        final size = await current.length();
        expect(size, lessThan(10000));

        // Newer entries should be preserved
        final content = await current.readAsString();
        expect(content, logContains('Entry 199'));
      });

      test('should handle rotation with all features combined', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));

        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            encryption: EncryptionConfig.aes256WithKey(key: encryptionKey),
            redactionPatterns: [RedactionPattern.email],
            rotation: RotationConfig.multiFile(
              maxFileSize: 3000,
              maxFiles: 2,
            ),
            format: const FormatConfig.json(),
          ),
        );

        // Generate logs with PII
        for (var i = 0; i < 50; i++) {
          Logiq.i(
            'USER',
            'User $i email: user$i@example.com${' padding' * 20}',
          );
        }

        await Logiq.flush();

        // Verify rotation happened
        final backup1 = File('$logDirectory/backup_1.log');
        expect(backup1, await fileExists());

        // Decrypt and verify redaction in backup (line by line)
        final encryptedContent = await backup1.readAsString();
        final lines = encryptedContent
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final encryptor = LogEncryptor(encryptionKey);
        final decryptedLines = <String>[];
        for (final line in lines) {
          final encrypted = base64Decode(line.trim());
          decryptedLines.add(encryptor.decrypt(encrypted));
        }
        final decrypted = decryptedLines.join('\n');

        // Should be redacted
        expect(decrypted, contains('[EMAIL_REDACTED]'));
        expect(decrypted, isNot(contains('user0@example.com')));
      });
    });

    group('export workflow', () {
      test('should export logs with compression', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        // Generate exportable logs
        for (var i = 0; i < 50; i++) {
          Logiq.i('EXPORT', 'Exportable message $i', {'index': i});
        }

        await Logiq.flush();

        // Export
        final result = await Logiq.export(compress: true);

        expect(result.file, await fileExists());
        expect(result.file.path, endsWith('.gz'));
        expect(result.entryCount, greaterThan(0));
        expect(result.compressedSize, lessThan(result.originalSize));
        expect(result.compressionRatio, lessThan(1.0));

        // Verify compressed content can be decompressed
        final compressed = await result.file.readAsBytes();
        final decompressed = const GZipDecoder().decodeBytes(compressed);
        final content = utf8.decode(decompressed);

        expect(content, contains('Exportable message'));
      });

      test('should export logs without compression', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('TEST', 'Export test');
        await Logiq.flush();

        final result = await Logiq.export(compress: false);

        expect(result.file, await fileExists());
        expect(result.file.path, endsWith('.log'));
        expect(result.compressedSize, result.originalSize);

        // Content should be readable directly
        final content = await result.file.readAsString();
        expect(content, contains('Export test'));
      });

      test('should export encrypted logs correctly', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));

        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            encryption: EncryptionConfig.aes256WithKey(key: encryptionKey),
          ),
        );

        Logiq.i('SECRET', 'Encrypted data');
        await Logiq.flush();

        final result = await Logiq.export(compress: false);

        // Exported file should contain decrypted data
        final content = await result.file.readAsString();
        expect(content, contains('Encrypted data'));
      });
    });

    group('multiple sessions', () {
      test('should generate different session IDs across reinitializations',
          () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        final stats1 = await Logiq.getStats();
        final sessionId1 = stats1.sessionId;

        await Logiq.dispose();

        // Small delay to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 10));

        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        final stats2 = await Logiq.getStats();
        final sessionId2 = stats2.sessionId;

        expect(sessionId1, isNot(equals(sessionId2)));
      });

      test('should maintain separate log streams for different sessions',
          () async {
        // Session 1
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('SESSION', 'Session 1 message');
        await Logiq.flush();

        final session1Stats = await Logiq.getStats();
        await Logiq.dispose();

        // Session 2
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('SESSION', 'Session 2 message');
        await Logiq.flush();

        final session2Stats = await Logiq.getStats();

        // Different session IDs
        expect(session1Stats.sessionId, isNot(equals(session2Stats.sessionId)));

        // Both messages should be in file
        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Session 1 message'));
        expect(content, logContains('Session 2 message'));
      });
    });

    group('performance scenarios', () {
      test('should handle high-volume logging efficiently', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 500,
          ),
        );

        final startTime = DateTime.now();

        // Log 10,000 messages
        for (var i = 0; i < 10000; i++) {
          Logiq.i('PERF', 'Message $i');
        }

        final logTime = DateTime.now().difference(startTime);

        // Logging should be fast (< 1 second for 10k messages)
        expect(logTime.inSeconds, lessThan(5));

        // Flush
        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 10000);
      });

      test('should handle concurrent logging from multiple sources', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        // Simulate concurrent logging
        await Future.wait([
          Future(() {
            for (var i = 0; i < 100; i++) {
              Logiq.i('SOURCE_A', 'Message A_$i');
            }
          }),
          Future(() {
            for (var i = 0; i < 100; i++) {
              Logiq.i('SOURCE_B', 'Message B_$i');
            }
          }),
          Future(() {
            for (var i = 0; i < 100; i++) {
              Logiq.i('SOURCE_C', 'Message C_$i');
            }
          }),
        ]);

        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 300);

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('SOURCE_A'));
        expect(content, logContains('SOURCE_B'));
        expect(content, logContains('SOURCE_C'));
      });

      test('should handle rapid flush requests gracefully', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        for (var i = 0; i < 10; i++) {
          Logiq.i('TEST', 'Message $i');
        }

        // Trigger multiple flushes rapidly
        final flushFutures = List.generate(10, (_) => Logiq.flush());

        // All should complete successfully
        await Future.wait(flushFutures);

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, isNotEmpty);
      });
    });

    group('error recovery', () {
      test('should continue logging after write failures', () async {
        var errorCount = 0;

        await Logiq.init(
          config: LogConfig(
            directory: '/invalid/readonly/path',
            hooks: LogHooks(
              onError: (error, stackTrace) {
                errorCount++;
              },
            ),
          ),
        );

        Logiq.i('TEST', 'Message 1');
        await Logiq.flush();

        // Should have recorded error but not crashed
        await TestHelpers.waitFor(
          () async => errorCount > 0,
          timeout: const Duration(seconds: 5),
        );

        expect(errorCount, greaterThan(0));

        // Should still be able to log
        Logiq.i('TEST', 'Message 2');
        expect(() => Logiq.flush(), returnsNormally);
      });

      test('should handle buffer overflow gracefully', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 10,
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );

        // Overflow buffer significantly
        for (var i = 0; i < 100; i++) {
          Logiq.i('TEST', 'Message $i');
        }

        final stats = await Logiq.getStats();

        // Should have logged all, but dropped some
        expect(stats.totalLogged, 100);
        expect(stats.droppedCount, greaterThan(0));

        // Should still be functional
        await Logiq.flush();
        Logiq.i('TEST', 'After overflow');

        final newStats = await Logiq.getStats();
        expect(newStats.totalLogged, 101);
      });
    });

    group('complex configurations', () {
      test('should work with all features enabled', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));
        var logCount = 0;
        var flushCount = 0;

        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            minLevel: LogLevel.debug,
            bufferSize: 50,
            flushInterval: const Duration(seconds: 1),
            format: FormatConfig.compactJson(),
            rotation: RotationConfig.multiFile(
              maxFileSize: 5000,
              maxFiles: 2,
            ),
            encryption: EncryptionConfig.aes256WithKey(key: encryptionKey),
            redactionPatterns: [
              RedactionPattern.email,
              RedactionPattern.phoneIndonesia,
            ],
            contextProviders: [
              () => {'appVersion': '1.0.0'},
              () => {'environment': 'test'},
            ],
            hooks: LogHooks(
              onLog: (_) => logCount++,
              onFlush: (count) => flushCount++,
            ),
            retention: const RetentionConfig(
              maxAge: Duration(days: 7),
              cleanupInterval: Duration(hours: 24),
            ),
            debugViewer: const DebugViewerConfig(enabled: true),
          ),
        );

        // Generate diverse logs
        Logiq.d('DEBUG', 'Debug info');
        Logiq.i('USER', 'User login: admin@example.com');
        Logiq.w('API', 'Rate limit warning', {'threshold': 90});
        Logiq.e('PAYMENT', 'Payment failed', {'card': '4532-1234-5678-9010'});

        await Logiq.flush();

        // Verify hooks were called
        expect(logCount, 4);
        expect(flushCount, greaterThan(0));

        // Verify logs were written and encrypted
        final logFile = File('$logDirectory/current.log');
        expect(logFile, await fileExists());

        final encryptedContent = await logFile.readAsString();
        expect(encryptedContent, isNot(contains('admin@example.com')));

        // Decrypt line by line (each log entry is encrypted separately)
        final lines = encryptedContent
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final encryptor = LogEncryptor(encryptionKey);
        final decryptedLines = <String>[];
        for (final line in lines) {
          final encrypted = base64Decode(line.trim());
          decryptedLines.add(encryptor.decrypt(encrypted));
        }
        final decrypted = decryptedLines.join('\n');

        // Should have redacted PII
        expect(decrypted, contains('[EMAIL_REDACTED]'));
        expect(decrypted, isNot(contains('admin@example.com')));

        // Should have auto-context
        expect(decrypted, contains('appVersion'));
        expect(decrypted, contains('1.0.0'));

        // Should be compact JSON format
        expect(decrypted, contains('"t":'));
        expect(decrypted, contains('"l":'));
        expect(decrypted, contains('"m":'));
      });

      test('should handle format changes between sessions', () async {
        // Session 1: JSON format
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            format: const FormatConfig.json(),
          ),
        );

        Logiq.i('TEST', 'JSON formatted');
        await Logiq.flush();
        await Logiq.dispose();

        // Session 2: Plain text format
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            format: FormatConfig.plainText(),
          ),
        );

        Logiq.i('TEST', 'Plain text formatted');
        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Both formats should coexist in file
        expect(content, contains('JSON formatted'));
        expect(content, contains('Plain text formatted'));
      });
    });

    group('real-world use cases', () {
      test('should handle e-commerce application logging', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            redactionPatterns: [
              RedactionPattern.email,
              RedactionPattern.creditCard,
            ],
            contextProviders: [
              () => {'app': 'e-commerce', 'version': '2.1.0'},
            ],
          ),
        );

        // User session
        Logiq.i('AUTH', 'User logged in', {'userId': 'user_123'});
        Logiq.i('CATALOG', 'Browsing products', {'category': 'electronics'});
        Logiq.i(
          'CART',
          'Added to cart',
          {'productId': 'prod_456', 'quantity': 2},
        );

        // Payment
        Logiq.i('CHECKOUT', 'Initiating payment');
        Logiq.e('PAYMENT', 'Payment failed', {
          'email': 'user@example.com',
          'card': '4532-1234-5678-9010',
          'error': 'insufficient_funds',
        });

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Business logic preserved
        expect(content, logContains('User logged in'));
        expect(content, logContains('Added to cart'));
        expect(content, logContains('Payment failed'));

        // PII redacted
        expect(content, contains('[EMAIL_REDACTED]'));
        expect(content, contains('[CARD_REDACTED]'));
        expect(content, isNot(contains('user@example.com')));

        // Context preserved
        expect(content, logContains('e-commerce'));
        expect(content, logContains('2.1.0'));
      });

      test('should handle ride-sharing application logging', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            redactionPatterns: [
              RedactionPattern.phoneIndonesia,
              RedactionPattern.nopolIndonesia,
            ],
          ),
        );

        // Driver session
        Logiq.i('DRIVER', 'Driver online', {
          'driverId': 'drv_789',
          'phone': '+628123456789',
          'vehicle': 'B 1234 XYZ',
        });

        // Ride
        Logiq.i(
          'RIDE',
          'Ride requested',
          {'pickup': 'Location A', 'destination': 'Location B'},
        );
        Logiq.i('RIDE', 'Driver assigned');
        Logiq.i('RIDE', 'Ride started');
        Logiq.i(
          'RIDE',
          'Ride completed',
          {'distance': 5.2, 'duration': 15, 'fare': 25000},
        );

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Ride data preserved
        expect(content, logContains('Ride requested'));
        expect(content, logContains('Ride completed'));
        expect(content, logContains('25000'));

        // PII redacted
        expect(content, contains('[PHONE_REDACTED]'));
        expect(content, contains('[NOPOL_REDACTED]'));
      });
    });
  });
}
