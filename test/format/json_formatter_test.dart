import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/format/json_formatter.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('JsonFormatter', () {
    late JsonFormatter formatter;

    setUp(() {
      formatter = const JsonFormatter();
    });

    group('format()', () {
      test('should format entry as valid JSON', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45, 123),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test message',
          context: {'key': 'value'},
          sessionId: 'sess_123',
          sequenceNumber: 42,
        );

        final output = formatter.format(entry);

        // Should be valid JSON
        final json = jsonDecode(output) as Map<String, dynamic>;
        expect(json['timestamp'], '2025-01-15T10:30:45.123Z');
        expect(json['level'], 'info');
        expect(json['category'], 'TEST');
        expect(json['message'], 'Test message');
        expect(json['context'], {'key': 'value'});
        expect(json['sessionId'], 'sess_123');
        expect(json['seq'], 42);
      });

      test('should format entry without optional fields', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.debug,
          category: 'APP',
          message: 'Application started',
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json.containsKey('timestamp'), isTrue);
        expect(json.containsKey('level'), isTrue);
        expect(json.containsKey('category'), isTrue);
        expect(json.containsKey('message'), isTrue);
        expect(json.containsKey('context'), isFalse);
        expect(json.containsKey('sessionId'), isFalse);
        expect(json.containsKey('seq'), isFalse);
      });

      test('should handle special characters in message', () {
        final entry = TestHelpers.createTestLogEntry(
          message: 'Message with "quotes" and \nnewlines',
        );

        final output = formatter.format(entry);
        expect(() => jsonDecode(output), returnsNormally);

        final json = jsonDecode(output) as Map<String, dynamic>;
        expect(json['message'], 'Message with "quotes" and \nnewlines');
      });

      test('should format all log levels correctly', () {
        for (final level in LogLevel.values) {
          final entry = TestHelpers.createTestLogEntry(level: level);
          final output = formatter.format(entry);
          final json = jsonDecode(output) as Map<String, dynamic>;

          expect(json['level'], level.name);
        }
      });

      test('should handle complex nested context', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {
            'string': 'value',
            'number': 42,
            'bool': true,
            'null': null,
            'list': [1, 2, 3],
            'nested': {
              'inner': 'value',
              'deep': {
                'key': 'value',
              },
            },
          },
        );

        final output = formatter.format(entry);
        expect(() => jsonDecode(output), returnsNormally);

        final json = jsonDecode(output) as Map<String, dynamic>;
        final context = json['context'] as Map<String, dynamic>;
        expect(context['string'], 'value');
        expect(context['number'], 42);
        expect(context['bool'], true);
        expect(context['null'], isNull);
        expect(context['list'], [1, 2, 3]);
        expect(context['nested']['inner'], 'value');
        expect(context['nested']['deep']['key'], 'value');
      });
    });

    group('formatAll()', () {
      test('should format multiple entries as NDJSON (newline-delimited)', () {
        final entries = [
          TestHelpers.createTestLogEntry(message: 'First'),
          TestHelpers.createTestLogEntry(message: 'Second'),
          TestHelpers.createTestLogEntry(message: 'Third'),
        ];

        final output = formatter.formatAll(entries);
        final lines = output.split('\n');

        expect(lines.length, 3);
        for (final line in lines) {
          expect(() => jsonDecode(line), returnsNormally);
        }

        final firstJson = jsonDecode(lines[0]) as Map<String, dynamic>;
        expect(firstJson['message'], 'First');
      });

      test('should handle empty list', () {
        final output = formatter.formatAll([]);
        expect(output, isEmpty);
      });

      test('should produce valid NDJSON', () {
        final entries = List.generate(
          100,
          (i) => TestHelpers.createTestLogEntry(message: 'Message $i'),
        );

        final output = formatter.formatAll(entries);
        final lines = output.split('\n');

        expect(lines.length, 100);
        for (var i = 0; i < lines.length; i++) {
          final json = jsonDecode(lines[i]) as Map<String, dynamic>;
          expect(json['message'], 'Message $i');
        }
      });
    });

    group('metadata', () {
      test('should have correct file extension', () {
        expect(formatter.fileExtension, 'jsonl');
      });

      test('should have correct MIME type', () {
        expect(formatter.mimeType, 'application/x-ndjson');
      });
    });

    group('serialization consistency', () {
      test('should produce same output as LogEntry.toJson()', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {'test': 'value'},
          sessionId: 'sess_test',
          sequenceNumber: 123,
        );

        final formatterOutput = formatter.format(entry);
        final expectedOutput = jsonEncode(entry.toJson());

        expect(formatterOutput, expectedOutput);
      });

      test('output should be reversible', () {
        final original = TestHelpers.createTestLogEntry(
          level: LogLevel.warning,
          category: 'WARN',
          message: 'Warning message',
          context: {'severity': 'medium'},
        );

        final output = formatter.format(original);
        final json = jsonDecode(output) as Map<String, dynamic>;
        final reconstructed = LogEntry.fromJson(json);

        expect(reconstructed.level, original.level);
        expect(reconstructed.category, original.category);
        expect(reconstructed.message, original.message);
        expect(reconstructed.context, original.context);
      });
    });

    group('edge cases', () {
      test('should handle empty strings', () {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          category: '',
          message: '',
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['category'], '');
        expect(json['message'], '');
      });

      test('should handle very long messages', () {
        final longMessage = 'x' * 10000;
        final entry = TestHelpers.createTestLogEntry(message: longMessage);

        final output = formatter.format(entry);
        expect(() => jsonDecode(output), returnsNormally);

        final json = jsonDecode(output) as Map<String, dynamic>;
        expect(json['message'], longMessage);
      });

      test('should handle unicode characters', () {
        final entry = TestHelpers.createTestLogEntry(
          message: '🎉 Hello 世界 مرحبا',
          context: {'emoji': '🔥', 'chinese': '你好'},
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['message'], '🎉 Hello 世界 مرحبا');
        expect(json['context']['emoji'], '🔥');
        expect(json['context']['chinese'], '你好');
      });
    });

    group('real-world examples', () {
      test('should format API request log', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 14, 30, 45),
          level: LogLevel.info,
          category: 'API',
          message: 'HTTP request received',
          context: {
            'method': 'POST',
            'path': '/api/users',
            'ip': '192.168.1.100',
            'userAgent': 'Mozilla/5.0',
            'requestId': 'req_12345',
          },
          sessionId: 'sess_abc123',
          sequenceNumber: 1001,
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['category'], 'API');
        expect(json['context']['method'], 'POST');
        expect(json['context']['requestId'], 'req_12345');
      });

      test('should format database error log', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 14, 30, 45),
          level: LogLevel.error,
          category: 'DATABASE',
          message: 'Query execution failed',
          context: {
            'query': 'SELECT * FROM users WHERE id = ?',
            'error': 'connection_timeout',
            'duration_ms': 5000,
            'retries': 3,
          },
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['level'], 'error');
        expect(json['category'], 'DATABASE');
        expect(json['context']['error'], 'connection_timeout');
      });
    });
  });
}
