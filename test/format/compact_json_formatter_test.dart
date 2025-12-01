import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/format/compact_json_formatter.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('CompactJsonFormatter', () {
    late CompactJsonFormatter formatter;

    setUp(() {
      formatter = const CompactJsonFormatter();
    });

    group('format()', () {
      test('should format entry as compact JSON with shortened keys', () {
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
        final json = jsonDecode(output) as Map<String, dynamic>;

        // Verify shortened keys
        expect(json['t'], 1736937045123); // timestamp as milliseconds
        expect(json['l'], 2); // LogLevel.info.value
        expect(json['c'], 'TEST'); // category
        expect(json['m'], 'Test message'); // message
        expect(json['x'], {'key': 'value'}); // context
        expect(json['s'], 'sess_123'); // sessionId
        expect(json['n'], 42); // sequenceNumber
      });

      test('should use correct level values', () {
        final levels = {
          LogLevel.verbose: 0,
          LogLevel.debug: 1,
          LogLevel.info: 2,
          LogLevel.warning: 3,
          LogLevel.error: 4,
          LogLevel.fatal: 5,
        };

        for (final entry in levels.entries) {
          final logEntry = TestHelpers.createTestLogEntry(level: entry.key);
          final output = formatter.format(logEntry);
          final json = jsonDecode(output) as Map<String, dynamic>;

          expect(json['l'], entry.value);
        }
      });

      test('should omit optional fields when not present', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test',
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json.containsKey('t'), isTrue);
        expect(json.containsKey('l'), isTrue);
        expect(json.containsKey('c'), isTrue);
        expect(json.containsKey('m'), isTrue);
        expect(json.containsKey('x'), isFalse); // No context
        expect(json.containsKey('s'), isFalse); // No sessionId
        expect(json.containsKey('n'), isFalse); // No sequenceNumber
      });

      test('should be significantly smaller than regular JSON', () {
        final entry = TestHelpers.createTestLogEntry(
          category: 'CATEGORY',
          message: 'This is a message',
          context: {'key1': 'value1', 'key2': 'value2'},
          sessionId: 'session_12345',
          sequenceNumber: 999,
        );

        final compactOutput = formatter.format(entry);
        final regularOutput = jsonEncode(entry.toJson());

        // Compact should be smaller
        expect(compactOutput.length, lessThan(regularOutput.length));
      });
    });

    group('formatAll()', () {
      test('should format multiple entries as NDJSON', () {
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
          final json = jsonDecode(line) as Map<String, dynamic>;
          expect(json.containsKey('m'), isTrue);
        }
      });

      test('should handle empty list', () {
        final output = formatter.formatAll([]);
        expect(output, isEmpty);
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
      test('should produce same output as LogEntry.toCompactJson()', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {'test': 'value'},
          sessionId: 'sess_test',
          sequenceNumber: 123,
        );

        final formatterOutput = formatter.format(entry);
        final expectedOutput = jsonEncode(entry.toCompactJson());

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
        final reconstructed = LogEntry.fromCompactJson(json);

        expect(reconstructed.level, original.level);
        expect(reconstructed.category, original.category);
        expect(reconstructed.message, original.message);
        expect(reconstructed.context, original.context);
      });
    });

    group('space savings', () {
      test('should save significant space on large datasets', () {
        final entries = List.generate(
          100,
          (i) => TestHelpers.createTestLogEntry(
            message: 'Test message $i',
            context: {'index': i, 'data': 'value'},
            sessionId: 'sess_$i',
            sequenceNumber: i,
          ),
        );

        final compactOutput = formatter.formatAll(entries);
        final regularOutput =
            entries.map((e) => jsonEncode(e.toJson())).join('\n');

        final savings = 1 - (compactOutput.length / regularOutput.length);
        // Should save at least 20% space
        expect(savings, greaterThan(0.2));
      });
    });

    group('edge cases', () {
      test('should handle very large timestamps', () {
        final entry = LogEntry(
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            9999999999999,
            isUtc: true,
          ),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test',
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['t'], 9999999999999);
      });

      test('should handle nested context correctly', () {
        final entry = TestHelpers.createTestLogEntry(
          context: {
            'level1': {
              'level2': {
                'level3': 'deep_value',
              },
            },
          },
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['x']['level1']['level2']['level3'], 'deep_value');
      });

      test('should handle unicode in compact format', () {
        final entry = TestHelpers.createTestLogEntry(
          message: '🚀 Rocket launch 发射',
          context: {'emoji': '⚡', 'lang': '中文'},
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['m'], '🚀 Rocket launch 发射');
        expect(json['x']['emoji'], '⚡');
        expect(json['x']['lang'], '中文');
      });
    });

    group('real-world examples', () {
      test('should format high-frequency logs efficiently', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45, 123),
          level: LogLevel.verbose,
          category: 'PERF',
          message: 'Frame rendered',
          context: {
            'fps': 60,
            'ms': 16.7,
          },
          sequenceNumber: 12345,
        );

        final output = formatter.format(entry);

        // Should be valid JSON
        expect(() => jsonDecode(output), returnsNormally);

        // Should be compact
        expect(output.length, lessThan(150));

        final json = jsonDecode(output) as Map<String, dynamic>;
        expect(json['l'], 0); // verbose
        expect(json['c'], 'PERF');
        expect(json['x']['fps'], 60);
      });

      test('should format IoT sensor data compactly', () {
        final entry = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.info,
          category: 'SENSOR',
          message: 'Temperature reading',
          context: {
            'temp': 22.5,
            'humidity': 45.2,
            'device': 'sensor_01',
          },
          sequenceNumber: 98765,
        );

        final output = formatter.format(entry);
        final json = jsonDecode(output) as Map<String, dynamic>;

        expect(json['c'], 'SENSOR');
        expect(json['x']['temp'], 22.5);
        expect(json['x']['device'], 'sensor_01');
        expect(json['n'], 98765);
      });
    });
  });
}
