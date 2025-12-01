import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/writer/file_writer.dart';
import 'package:logiq/src/writer/write_params.dart';
import 'package:logiq/src/security/log_encryptor.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('FileWriter', () {
    late Directory tempDir;
    late String logDirectory;

    setUp(() async {
      tempDir = await TestHelpers.createTempDirectory();
      logDirectory = '${tempDir.path}/logs';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('basic file writing', () {
      test('should create log directory if not exists', () async {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Test entry'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        expect(Directory(logDirectory), await directoryExists());
      });

      test('should write log entries to current.log', () async {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Entry 1'),
          TestHelpers.createTestLogEntry(message: 'Entry 2'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final logFile = File('$logDirectory/current.log');
        expect(logFile, await fileExists());

        final content = await logFile.readAsString();
        expect(content, contains('Entry 1'));
        expect(content, contains('Entry 2'));
      });

      test('should append to existing log file', () async {
        // Write first batch
        final firstEntries = [
          TestHelpers.createTestLogEntry(message: 'First batch'),
        ];

        final params1 = WriteParams(
          entries: firstEntries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params1.toMap());

        // Write second batch
        final secondEntries = [
          TestHelpers.createTestLogEntry(message: 'Second batch'),
        ];

        final params2 = WriteParams(
          entries: secondEntries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params2.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, contains('First batch'));
        expect(content, contains('Second batch'));
      });

      test('should write empty list without error', () async {
        final params = WriteParams(
          entries: [],
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        expect(() => FileWriter.writeEntries(params.toMap()), returnsNormally);
      });
    });

    group('formatting', () {
      test('should format entries as JSON', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            level: LogLevel.info,
            message: 'Test message',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();

        // Should be valid JSON
        for (final line in lines) {
          expect(() => jsonDecode(line), returnsNormally);
          final json = jsonDecode(line) as Map<String, dynamic>;
          expect(json['level'], 'info');
          expect(json['message'], 'Test message');
        }
      });

      test('should format entries as compact JSON', () async {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Compact test'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.compactJson.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();

        // Should have shortened keys
        for (final line in lines) {
          final json = jsonDecode(line) as Map<String, dynamic>;
          expect(json.containsKey('t'), isTrue); // timestamp
          expect(json.containsKey('l'), isTrue); // level
          expect(json.containsKey('m'), isTrue); // message
        }
      });

      test('should format entries as plain text', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            level: LogLevel.error,
            category: 'TEST',
            message: 'Error message',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.plainText.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, contains('[ERROR'));
        expect(content, contains('[TEST]'));
        expect(content, contains('Error message'));
      });

      test('should format entries as CSV', () async {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'CSV entry'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.csv.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Should be CSV format (comma-separated)
        expect(content, contains('CSV entry'));
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
        expect(lines.first.split(',').length, greaterThanOrEqualTo(5));
      });
    });

    group('redaction', () {
      test('should redact email addresses from message', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'User email is user@example.com',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [
            {
              'name': 'email',
              'pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
              'replacement': '[EMAIL_REDACTED]',
            },
          ],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, contains('[EMAIL_REDACTED]'));
        expect(content, isNot(contains('user@example.com')));
      });

      test('should redact sensitive data from context', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'User login',
            context: {
              'email': 'admin@example.com',
              'ip': '192.168.1.1',
            },
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [
            {
              'name': 'email',
              'pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
              'replacement': '[EMAIL_REDACTED]',
            },
          ],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, contains('[EMAIL_REDACTED]'));
        expect(content, isNot(contains('admin@example.com')));
        expect(content, contains('192.168.1.1')); // IP not redacted
      });

      test('should apply multiple redaction patterns', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'User: user@test.com, Phone: 081234567890',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [
            {
              'name': 'email',
              'pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
              'replacement': '[EMAIL]',
            },
            {
              'name': 'phone',
              'pattern': r'08[1-9][0-9]{6,10}',
              'replacement': '[PHONE]',
            },
          ],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, contains('[EMAIL]'));
        expect(content, contains('[PHONE]'));
      });

      test('should work with no redaction patterns', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'user@example.com',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, contains('user@example.com')); // Not redacted
      });
    });

    group('encryption', () {
      test('should encrypt log data when encryption key provided', () async {
        final encryptionKey = Uint8List.fromList(
          utf8.encode('12345678901234567890123456789012'),
        ); // 32 chars
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Secret message'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
          encryptionKey: encryptionKey,
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Content should be base64-encoded encrypted data
        expect(content, isNot(contains('Secret message')));
        expect(() => base64Decode(content.trim()), returnsNormally);
      });

      test('should be able to decrypt encrypted logs', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Decrypt me'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
          encryptionKey: encryptionKey,
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        final encrypted = base64Decode(content.trim());

        final encryptor = LogEncryptor(encryptionKey);
        final decrypted = encryptor.decrypt(encrypted);

        expect(decrypted, contains('Decrypt me'));
      });

      test('should not encrypt when no encryption key', () async {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Plain text'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Should contain plaintext
        expect(content, contains('Plain text'));
      });
    });

    group('multi-file rotation', () {
      test('should rotate file when size exceeds maxFileSize', () async {
        final entries = List.generate(
          100,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i with some padding text to increase size' * 10,
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 5000, // Small size to trigger rotation
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        // Should have rotated files
        final backup1 = File('$logDirectory/backup_1.log');
        final current = File('$logDirectory/current.log');

        expect(backup1, await fileExists());
        expect(current, await fileExists());
      });

      test('should maintain backup files up to maxFiles', () async {
        // Write multiple times to trigger multiple rotations
        for (var batch = 0; batch < 5; batch++) {
          final entries = List.generate(
            50,
            (i) => TestHelpers.createTestLogEntry(
              message: 'Batch $batch Entry $i${' padding' * 50}',
            ),
          );

          final params = WriteParams(
            entries: entries,
            logDirectory: logDirectory,
            formatType: LogFormat.json.index,
            rotationStrategy: RotationStrategy.multiFile.index,
            maxFileSize: 3000, // Small to trigger rotation
            maxFiles: 3,
            trimPercent: 25,
            redactionPatterns: [],
          );

          await FileWriter.writeEntries(params.toMap());
        }

        // Should have at most maxFiles (3) backup files
        final backup1 = File('$logDirectory/backup_1.log');
        final backup2 = File('$logDirectory/backup_2.log');
        final backup4 = File('$logDirectory/backup_4.log');

        expect(await backup1.exists(), isTrue);
        expect(await backup2.exists(), isTrue);

        // backup_4 should not exist (maxFiles = 3)
        expect(await backup4.exists(), isFalse);
      });

      test('should preserve data in rotated files', () async {
        final firstEntries = [
          TestHelpers.createTestLogEntry(
            message: 'First entry${' padding' * 100}',
          ),
        ];

        final params1 = WriteParams(
          entries: firstEntries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 500, // Small to trigger rotation on next write
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params1.toMap());

        // Write again to trigger rotation
        final secondEntries = [
          TestHelpers.createTestLogEntry(
            message: 'Second entry${' padding' * 100}',
          ),
        ];

        final params2 = WriteParams(
          entries: secondEntries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 500,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params2.toMap());

        // First entry should be in backup_1.log
        final backup1Content =
            await TestHelpers.readLogFile('$logDirectory/backup_1.log');
        expect(backup1Content, contains('First entry'));
      });

      test('should create new current.log after rotation', () async {
        final entries = List.generate(
          50,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i${' padding' * 50}',
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 2000,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final current = File('$logDirectory/current.log');
        expect(current, await fileExists());

        // New current.log should be smaller than maxFileSize (since it's new)
        final size = await current.length();
        expect(size, lessThan(2000));
      });
    });

    group('single-file rotation', () {
      test('should trim oldest entries when file exceeds maxFileSize',
          () async {
        // Write initial entries
        final entries = List.generate(
          100,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i${' padding' * 20}',
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.singleFile.index,
          maxFileSize: 5000, // Small to trigger trimming
          maxFiles: 3,
          trimPercent: 25, // Trim 25% of oldest entries
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final current = File('$logDirectory/current.log');
        final size = await current.length();

        // Size should be reduced after trimming
        expect(size, lessThan(10000));
      });

      test('should only have current.log (no backup files)', () async {
        final entries = List.generate(
          100,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i${' padding' * 30}',
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.singleFile.index,
          maxFileSize: 3000,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        // Should only have current.log, no backups
        final backup1 = File('$logDirectory/backup_1.log');
        expect(await backup1.exists(), isFalse);

        final current = File('$logDirectory/current.log');
        expect(current, await fileExists());
      });

      test('should preserve newer entries after trim', () async {
        final entries = List.generate(
          50,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i${' padding' * 30}',
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.singleFile.index,
          maxFileSize: 3000,
          maxFiles: 3,
          trimPercent: 50, // Trim 50%
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // Newer entries should be preserved
        expect(content, contains('Entry 49'));

        // Oldest entries should be removed
        expect(content, isNot(contains('Entry 0')));
        expect(content, isNot(contains('Entry 1')));
      });
    });

    group('edge cases', () {
      test('should handle very large entry', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'x' * 100000, // 100KB message
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        expect(() => FileWriter.writeEntries(params.toMap()), returnsNormally);

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content.length, greaterThan(90000));
      });

      test('should handle unicode characters', () async {
        final entries = [
          TestHelpers.createTestLogEntry(
            message: '🎉 Hello 世界 مرحبا',
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, contains('🎉 Hello 世界 مرحبا'));
      });

      test('should handle special characters in path', () async {
        final specialDir = '${tempDir.path}/logs with spaces';
        final entries = [
          TestHelpers.createTestLogEntry(message: 'Test'),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: specialDir,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await FileWriter.writeEntries(params.toMap());

        final logFile = File('$specialDir/current.log');
        expect(logFile, await fileExists());
      });

      test('should handle rapid successive writes', () async {
        for (var i = 0; i < 10; i++) {
          final entries = [
            TestHelpers.createTestLogEntry(message: 'Rapid write $i'),
          ];

          final params = WriteParams(
            entries: entries,
            logDirectory: logDirectory,
            formatType: LogFormat.json.index,
            rotationStrategy: RotationStrategy.multiFile.index,
            maxFileSize: 1024 * 1024,
            maxFiles: 3,
            trimPercent: 25,
            redactionPatterns: [],
          );

          await FileWriter.writeEntries(params.toMap());
        }

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        // All writes should be present
        for (var i = 0; i < 10; i++) {
          expect(content, contains('Rapid write $i'));
        }
      });

      test('should handle empty entry fields gracefully', () async {
        final entries = [
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.info,
            category: '',
            message: '',
            context: null,
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        expect(() => FileWriter.writeEntries(params.toMap()), returnsNormally);
      });
    });

    group('integration scenarios', () {
      test('should handle full workflow: format + redact + encrypt + write',
          () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));
        final entries = [
          TestHelpers.createTestLogEntry(
            message: 'User login: admin@example.com',
            context: {'ip': '192.168.1.1'},
          ),
        ];

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [
            {
              'name': 'email',
              'pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
              'replacement': '[EMAIL_REDACTED]',
            },
          ],
          encryptionKey: encryptionKey,
        );

        await FileWriter.writeEntries(params.toMap());

        // Read and decrypt
        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        final encrypted = base64Decode(content.trim());
        final encryptor = LogEncryptor(encryptionKey);
        final decrypted = encryptor.decrypt(encrypted);

        // Should be redacted
        expect(decrypted, contains('[EMAIL_REDACTED]'));
        expect(decrypted, isNot(contains('admin@example.com')));

        // Should still have other data
        expect(decrypted, contains('192.168.1.1'));
      });

      test('should handle rotation with encryption', () async {
        final encryptionKey =
            Uint8List.fromList(utf8.encode('12345678901234567890123456789012'));
        final entries = List.generate(
          50,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Encrypted entry $i${' padding' * 30}',
          ),
        );

        final params = WriteParams(
          entries: entries,
          logDirectory: logDirectory,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 3000,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
          encryptionKey: encryptionKey,
        );

        await FileWriter.writeEntries(params.toMap());

        // Should have rotated
        final backup1 = File('$logDirectory/backup_1.log');
        expect(backup1, await fileExists());

        // Backup should also be encrypted
        final backupContent = await backup1.readAsString();
        expect(backupContent, isNot(contains('Encrypted entry')));
      });

      test('should handle concurrent writes to different directories',
          () async {
        final dir1 = '${tempDir.path}/logs1';
        final dir2 = '${tempDir.path}/logs2';

        final entries1 = [TestHelpers.createTestLogEntry(message: 'Dir 1')];
        final entries2 = [TestHelpers.createTestLogEntry(message: 'Dir 2')];

        final params1 = WriteParams(
          entries: entries1,
          logDirectory: dir1,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        final params2 = WriteParams(
          entries: entries2,
          logDirectory: dir2,
          formatType: LogFormat.json.index,
          rotationStrategy: RotationStrategy.multiFile.index,
          maxFileSize: 1024 * 1024,
          maxFiles: 3,
          trimPercent: 25,
          redactionPatterns: [],
        );

        await Future.wait([
          FileWriter.writeEntries(params1.toMap()),
          FileWriter.writeEntries(params2.toMap()),
        ]);

        final content1 = await TestHelpers.readLogFile('$dir1/current.log');
        final content2 = await TestHelpers.readLogFile('$dir2/current.log');

        expect(content1, contains('Dir 1'));
        expect(content2, contains('Dir 2'));
      });
    });
  });
}
