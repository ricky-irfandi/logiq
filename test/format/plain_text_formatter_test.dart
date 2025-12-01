import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/format/plain_text_formatter.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('PlainTextFormatter', () {
    late PlainTextFormatter formatter;

    setUp(() {
      formatter = PlainTextFormatter();
    });

    group('format()', () {
      test('should format entry with all fields', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45, 123),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test message',
          context: {'key': 'value'},
        );

        final output = formatter.format(entry);

        expect(output, contains('[2025-01-15T10:30:45.123Z]'));
        expect(output, contains('[INFO   ]'));
        expect(output, contains('[TEST]'));
        expect(output, contains('Test message'));
        expect(output, contains('{"key":"value"}'));
      });

      test('should format entry without context', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Simple message',
          context: null,
        );

        final output = formatter.format(entry);

        expect(output, contains('Simple message'));
        expect(output, isNot(contains('{')));
      });

      test('should pad level names correctly', () {
        final levels = [
          LogLevel.verbose,
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
          LogLevel.fatal,
        ];

        for (final level in levels) {
          final entry = TestHelpers.createTestLogEntry(level: level);
          final output = formatter.format(entry);

          // Level should be uppercase and padded to 7 characters
          expect(output, contains('[${level.name.toUpperCase().padRight(7)}]'));
        }
      });

      test('should handle special characters in message', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Message with\nnewline and\ttab',
        );

        final output = formatter.format(entry);
        expect(output, contains('Message with\nnewline and\ttab'));
      });

      test('should format context as JSON', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {
            'string': 'value',
            'number': 42,
            'bool': true,
            'nested': {'key': 'value'},
          },
        );

        final output = formatter.format(entry);
        expect(output, contains('"string":"value"'));
        expect(output, contains('"number":42'));
        expect(output, contains('"bool":true'));
        expect(output, contains('"nested"'));
      });
    });

    group('custom timestamp format', () {
      test('should use custom timestamp format when provided', () {
        final formatter =
            PlainTextFormatter(timestampFormat: 'yyyy-MM-dd HH:mm:ss');
        final entry = LogEntry(
          timestamp: DateTime(2025, 1, 15, 10, 30, 45),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test',
        );

        final output = formatter.format(entry);
        expect(output, contains('[2025-01-15 10:30:45]'));
      });

      test('should use ISO8601 when no custom format', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45, 123),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test',
        );

        final output = formatter.format(entry);
        expect(output, contains('[2025-01-15T10:30:45.123Z]'));
      });
    });

    group('formatAll()', () {
      test('should format multiple entries with newlines', () {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'First'),
          TestHelpers.createTestLogEntry(message: 'Second'),
          TestHelpers.createTestLogEntry(message: 'Third'),
        ];

        final output = formatter.formatAll(entries);

        expect(output, contains('First'));
        expect(output, contains('Second'));
        expect(output, contains('Third'));
        expect(output.split('\n').length, 3);
      });

      test('should handle empty list', () {
        final output = formatter.formatAll([]);
        expect(output, isEmpty);
      });
    });

    group('metadata', () {
      test('should have correct file extension', () {
        expect(formatter.fileExtension, 'log');
      });

      test('should have correct MIME type', () {
        expect(formatter.mimeType, 'text/plain');
      });
    });

    group('real-world examples', () {
      test('should format API log correctly', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.info,
          category: 'API',
          message: 'Request completed',
          context: {
            'method': 'GET',
            'path': '/api/users',
            'status': 200,
            'duration': 125,
          },
        );

        final output = formatter.format(entry);

        expect(output, contains('[INFO   ]'));
        expect(output, contains('[API]'));
        expect(output, contains('Request completed'));
        expect(output, contains('"method":"GET"'));
        expect(output, contains('"status":200'));
      });

      test('should format error log correctly', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.error,
          category: 'DB',
          message: 'Connection failed',
          context: {
            'error': 'timeout',
            'host': 'localhost:5432',
            'retries': 3,
          },
        );

        final output = formatter.format(entry);

        expect(output, contains('[ERROR  ]'));
        expect(output, contains('[DB]'));
        expect(output, contains('Connection failed'));
        expect(output, contains('"error":"timeout"'));
      });
    });
  });
}
