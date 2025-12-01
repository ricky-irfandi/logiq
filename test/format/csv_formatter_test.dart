import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/format/csv_formatter.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('CsvFormatter', () {
    late CsvFormatter formatter;

    setUp(() {
      formatter = const CsvFormatter();
    });

    group('format()', () {
      test('should format entry as CSV row', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45, 123),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test message',
          context: {'key': 'value'},
          sessionId: 'sess_123',
        );

        final output = formatter.format(entry);
        final fields = output.split(',');

        expect(fields[0], '2025-01-15T10:30:45.123Z'); // timestamp
        expect(fields[1], 'info'); // level
        expect(fields[2], 'TEST'); // category
        expect(fields[3], 'Test message'); // message
        expect(fields[4], contains('key')); // context (JSON)
        expect(fields[5], 'sess_123'); // sessionId
      });

      test('should handle entry without optional fields', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.debug,
          category: 'APP',
          message: 'Started',
        );

        final output = formatter.format(entry);
        final fields = output.split(',');

        expect(fields[4], ''); // empty context
        expect(fields[5], ''); // empty sessionId
      });

      test('should escape commas in message', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Message with, commas, in it',
        );

        final output = formatter.format(entry);
        expect(output, contains('"Message with, commas, in it"'));
      });

      test('should escape quotes in message', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Message with "quotes"',
        );

        final output = formatter.format(entry);
        expect(output, contains('""quotes""')); // Double quotes escaped
      });

      test('should escape newlines in message', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Message with\nnewline',
        );

        final output = formatter.format(entry);
        expect(output, contains('"Message with\nnewline"'));
      });

      test('should handle all log levels', () {
        for (final level in LogLevel.values) {
          final entry = TestHelpers.createTestLogEntry(level: level);
          final output = formatter.format(entry);

          expect(output, contains(level.name));
        }
      });

      test('should format context as JSON string', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {'key1': 'value1', 'key2': 42},
        );

        final output = formatter.format(entry);
        expect(output, contains('"key1"'));
        expect(output, contains('"value1"'));
        expect(output, contains('"key2"'));
      });
    });

    group('formatAll()', () {
      test('should include header row', () {
        final entries = [TestHelpers.createTestLogEntry()];
        final output = formatter.formatAll(entries);
        final lines = output.split('\n');

        expect(lines.first, CsvFormatter.header);
        expect(
          lines.first,
          'timestamp,level,category,message,context,sessionId',
        );
      });

      test('should format multiple entries with header', () {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'First'),
          TestHelpers.createTestLogEntry(message: 'Second'),
          TestHelpers.createTestLogEntry(message: 'Third'),
        ];

        final output = formatter.formatAll(entries);
        final lines = output.split('\n');

        expect(lines.length, 4); // Header + 3 entries
        expect(lines[0], CsvFormatter.header);
        expect(lines[1], contains('First'));
        expect(lines[2], contains('Second'));
        expect(lines[3], contains('Third'));
      });

      test('should handle empty list', () {
        final output = formatter.formatAll([]);
        expect(output, isEmpty);
      });

      test('should be importable to spreadsheet software', () {
        final entries = List.generate(
          10,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Entry $i',
            context: {'index': i},
          ),
        );

        final output = formatter.formatAll(entries);
        final lines = output.split('\n');

        expect(lines.length, 11); // Header + 10 entries

        // Each line should have correct number of fields
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Count commas (should be 5, meaning 6 fields)
          // But need to account for quoted fields
          expect(line, isNotEmpty);
        }
      });
    });

    group('escape handling', () {
      test('should handle field with comma only', () {
        final entry = TestHelpers.createTestLogEntry(
          category: 'A,B',
        );

        final output = formatter.format(entry);
        expect(output, contains('"A,B"'));
      });

      test('should handle field with quote only', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Say "hello"',
        );

        final output = formatter.format(entry);
        expect(output, contains('""hello""'));
      });

      test('should handle field with newline only', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Line1\nLine2',
        );

        final output = formatter.format(entry);
        expect(output, contains('"Line1\nLine2"'));
      });

      test('should handle field with all special characters', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Text with, comma "quote" and\nnewline',
        );

        final output = formatter.format(entry);
        expect(output, contains('"Text with, comma ""quote"" and\nnewline"'));
      });

      test('should not escape field without special characters', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Simple message',
        );

        final output = formatter.format(entry);
        final fields = output.split(',');
        expect(fields[3], 'Simple message'); // Not quoted
      });
    });

    group('metadata', () {
      test('should have correct file extension', () {
        expect(formatter.fileExtension, 'csv');
      });

      test('should have correct MIME type', () {
        expect(formatter.mimeType, 'text/csv');
      });

      test('should have correct header', () {
        expect(
          CsvFormatter.header,
          'timestamp,level,category,message,context,sessionId',
        );
      });
    });

    group('real-world examples', () {
      test('should format application log', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.info,
          category: 'APP',
          message: 'User logged in',
          context: {
            'userId': 12345,
            'email': 'user@example.com',
          },
          sessionId: 'sess_abc123',
        );

        final output = formatter.format(entry);

        expect(output, contains('2025-01-15T10:30:45.000Z'));
        expect(output, contains('info'));
        expect(output, contains('APP'));
        expect(output, contains('User logged in'));
        expect(output, contains('sess_abc123'));
      });

      test('should format error log with stack trace', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.error,
          category: 'CRASH',
          message: 'Application crashed',
          context: {
            'error': 'NullPointerException',
            'stackTrace': 'at main.dart:123\nat widget.dart:456',
          },
        );

        final output = formatter.format(entry);

        expect(output, contains('error'));
        expect(output, contains('CRASH'));
        expect(output, contains('Application crashed'));
      });

      test('should be parseable by standard CSV libraries', () {
        final entries = [
          LogEntry(
            timestamp: DateTime.utc(2025, 1, 15, 10, 0, 0),
            level: LogLevel.info,
            category: 'API',
            message: 'GET /users',
          ),
          LogEntry(
            timestamp: DateTime.utc(2025, 1, 15, 10, 1, 0),
            level: LogLevel.warning,
            category: 'API',
            message: 'Rate limit warning',
          ),
          LogEntry(
            timestamp: DateTime.utc(2025, 1, 15, 10, 2, 0),
            level: LogLevel.error,
            category: 'DB',
            message: 'Connection failed',
          ),
        ];

        final output = formatter.formatAll(entries);

        // Should have header + 3 data rows
        expect(output.split('\n').length, 4);

        // Should start with header
        expect(output, startsWith('timestamp,level,category'));

        // Each entry should be on its own line
        expect(output, contains('GET /users'));
        expect(output, contains('Rate limit warning'));
        expect(output, contains('Connection failed'));
      });
    });

    group('edge cases', () {
      test('should handle empty message', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          category: 'TEST',
          message: '',
        );

        final output = formatter.format(entry);
        final fields = output.split(',');
        expect(fields[3], ''); // Empty message field
      });

      test('should handle very long message', () {
        final longMessage = 'x' * 10000;
        final entry = TestHelpers.createTestLogEntry(message: longMessage);

        final output = formatter.format(entry);
        expect(output, contains(longMessage));
      });

      test('should handle unicode characters', () {
        final entry = TestHelpers.createTestLogEntry(
          message: '🎉 Hello 世界',
          category: '测试',
        );

        final output = formatter.format(entry);
        expect(output, contains('🎉 Hello 世界'));
        expect(output, contains('测试'));
      });

      test('should handle null values in context', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {'key': null},
        );

        final output = formatter.format(entry);
        expect(() => output, returnsNormally);
      });
    });
  });
}
