import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LogEntry', () {
    group('construction', () {
      test('should create entry with all required parameters', () {
        final timestamp = DateTime(2025, 1, 15, 10, 30, 45);
        final entry = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Test message',
        );

        expect(entry.timestamp, timestamp);
        expect(entry.level, LogLevel.info);
        expect(entry.category, 'TEST');
        expect(entry.message, 'Test message');
        expect(entry.context, isNull);
        expect(entry.sessionId, isNull);
        expect(entry.sequenceNumber, isNull);
      });

      test('should create entry with optional parameters', () {
        final timestamp = DateTime(2025, 1, 15, 10, 30, 45);
        final context = {'userId': 123, 'action': 'login'};
        final entry = LogEntry(
          timestamp: timestamp,
          level: LogLevel.warning,
          category: 'AUTH',
          message: 'Login attempt',
          context: context,
          sessionId: 'sess_123',
          sequenceNumber: 42,
        );

        expect(entry.timestamp, timestamp);
        expect(entry.level, LogLevel.warning);
        expect(entry.category, 'AUTH');
        expect(entry.message, 'Login attempt');
        expect(entry.context, context);
        expect(entry.sessionId, 'sess_123');
        expect(entry.sequenceNumber, 42);
      });
    });

    group('toJson()', () {
      test('should serialize to JSON with required fields', () {
        final timestamp = DateTime.utc(2025, 1, 15, 10, 30, 45, 123);
        final entry = LogEntry(
          timestamp: timestamp,
          level: LogLevel.error,
          category: 'DB',
          message: 'Connection failed',
        );

        final json = entry.toJson();

        expect(json['timestamp'], '2025-01-15T10:30:45.123Z');
        expect(json['level'], 'error');
        expect(json['category'], 'DB');
        expect(json['message'], 'Connection failed');
        expect(json.containsKey('context'), isFalse);
        expect(json.containsKey('sessionId'), isFalse);
        expect(json.containsKey('seq'), isFalse);
      });

      test('should serialize to JSON with all fields', () {
        final timestamp = DateTime.utc(2025, 1, 15, 10, 30, 45, 123);
        final context = {'error': 'timeout', 'retries': 3};
        final entry = LogEntry(
          timestamp: timestamp,
          level: LogLevel.error,
          category: 'DB',
          message: 'Connection failed',
          context: context,
          sessionId: 'sess_abc',
          sequenceNumber: 100,
        );

        final json = entry.toJson();

        expect(json['timestamp'], '2025-01-15T10:30:45.123Z');
        expect(json['level'], 'error');
        expect(json['category'], 'DB');
        expect(json['message'], 'Connection failed');
        expect(json['context'], context);
        expect(json['sessionId'], 'sess_abc');
        expect(json['seq'], 100);
      });

      test('should not include empty context', () {
        final entry = TestHelpers.createTestLogEntry(context: {});
        final json = entry.toJson();
        expect(json.containsKey('context'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize from JSON', () {
        final json = {
          'timestamp': '2025-01-15T10:30:45.123Z',
          'level': 'warning',
          'category': 'API',
          'message': 'Rate limit exceeded',
          'context': {'limit': 100, 'current': 150},
          'sessionId': 'sess_xyz',
          'seq': 50,
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.timestamp, DateTime.utc(2025, 1, 15, 10, 30, 45, 123));
        expect(entry.level, LogLevel.warning);
        expect(entry.category, 'API');
        expect(entry.message, 'Rate limit exceeded');
        expect(entry.context, {'limit': 100, 'current': 150});
        expect(entry.sessionId, 'sess_xyz');
        expect(entry.sequenceNumber, 50);
      });

      test('should handle missing optional fields', () {
        final json = {
          'timestamp': '2025-01-15T10:30:45.123Z',
          'level': 'info',
          'category': 'SYSTEM',
          'message': 'System started',
        };

        final entry = LogEntry.fromJson(json);

        expect(entry.context, isNull);
        expect(entry.sessionId, isNull);
        expect(entry.sequenceNumber, isNull);
      });

      test('should default to info level for invalid level', () {
        final json = {
          'timestamp': '2025-01-15T10:30:45.123Z',
          'level': 'invalid_level',
          'category': 'TEST',
          'message': 'Test',
        };

        final entry = LogEntry.fromJson(json);
        expect(entry.level, LogLevel.info);
      });
    });

    group('toCompactJson()', () {
      test('should serialize to compact JSON with shortened keys', () {
        final timestamp = DateTime.utc(2025, 1, 15, 10, 30, 45, 123);
        final context = {'key': 'value'};
        final entry = LogEntry(
          timestamp: timestamp,
          level: LogLevel.debug,
          category: 'NET',
          message: 'Request sent',
          context: context,
          sessionId: 'sess_123',
          sequenceNumber: 77,
        );

        final json = entry.toCompactJson();

        expect(json['t'], 1736937045123); // milliseconds since epoch
        expect(json['l'], 1); // LogLevel.debug.value
        expect(json['c'], 'NET');
        expect(json['m'], 'Request sent');
        expect(json['x'], context);
        expect(json['s'], 'sess_123');
        expect(json['n'], 77);
      });

      test('should not include empty context in compact JSON', () {
        final entry = TestHelpers.createTestLogEntry(context: {});
        final json = entry.toCompactJson();
        expect(json.containsKey('x'), isFalse);
      });
    });

    group('fromCompactJson()', () {
      test('should deserialize from compact JSON', () {
        final json = {
          't': 1736937045123,
          'l': 4, // LogLevel.error.value
          'c': 'CRASH',
          'm': 'Application crashed',
          'x': {'reason': 'null_pointer'},
          's': 'sess_crash',
          'n': 999,
        };

        final entry = LogEntry.fromCompactJson(json);

        expect(entry.timestamp, DateTime.utc(2025, 1, 15, 10, 30, 45, 123));
        expect(entry.level, LogLevel.error);
        expect(entry.category, 'CRASH');
        expect(entry.message, 'Application crashed');
        expect(entry.context, {'reason': 'null_pointer'});
        expect(entry.sessionId, 'sess_crash');
        expect(entry.sequenceNumber, 999);
      });

      test('should handle missing optional fields in compact JSON', () {
        final json = {
          't': 1736937045123,
          'l': 2,
          'c': 'APP',
          'm': 'Started',
        };

        final entry = LogEntry.fromCompactJson(json);
        expect(entry.context, isNull);
        expect(entry.sessionId, isNull);
        expect(entry.sequenceNumber, isNull);
      });

      test('should default to info level for invalid level value', () {
        final json = {
          't': 1736937045123,
          'l': 999, // Invalid
          'c': 'TEST',
          'm': 'Test',
        };

        final entry = LogEntry.fromCompactJson(json);
        expect(entry.level, LogLevel.info);
      });
    });

    group('copyWith()', () {
      test('should create copy with modified fields', () {
        final original = TestHelpers.createTestLogEntry(
          level: LogLevel.info,
          category: 'OLD',
          message: 'Old message',
        );

        final copy = original.copyWith(
          level: LogLevel.error,
          message: 'New message',
        );

        expect(copy.level, LogLevel.error);
        expect(copy.message, 'New message');
        expect(copy.category, 'OLD'); // Unchanged
        expect(copy.timestamp, original.timestamp); // Unchanged
      });

      test('should preserve original when no changes', () {
        final original = TestHelpers.createTestLogEntry();
        final copy = original.copyWith();

        expect(copy.timestamp, original.timestamp);
        expect(copy.level, original.level);
        expect(copy.category, original.category);
        expect(copy.message, original.message);
      });

      test('should handle all fields', () {
        final original = TestHelpers.createTestLogEntry();
        final newTimestamp = DateTime(2026, 1, 1);
        final newContext = {'new': 'data'};

        final copy = original.copyWith(
          timestamp: newTimestamp,
          level: LogLevel.fatal,
          category: 'NEW',
          message: 'New message',
          context: newContext,
          sessionId: 'new_session',
          sequenceNumber: 123,
        );

        expect(copy.timestamp, newTimestamp);
        expect(copy.level, LogLevel.fatal);
        expect(copy.category, 'NEW');
        expect(copy.message, 'New message');
        expect(copy.context, newContext);
        expect(copy.sessionId, 'new_session');
        expect(copy.sequenceNumber, 123);
      });
    });

    group('equality and hashCode', () {
      test('should be equal when all fields match', () {
        final timestamp = DateTime(2025, 1, 15);
        final entry1 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message',
          sequenceNumber: 1,
        );
        final entry2 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message',
          sequenceNumber: 1,
        );

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('should not be equal when timestamp differs', () {
        final entry1 = LogEntry(
          timestamp: DateTime(2025, 1, 15),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message',
        );
        final entry2 = LogEntry(
          timestamp: DateTime(2025, 1, 16),
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message',
        );

        expect(entry1, isNot(equals(entry2)));
      });

      test('should not be equal when level differs', () {
        final timestamp = DateTime(2025, 1, 15);
        final entry1 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message',
        );
        final entry2 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.error,
          category: 'TEST',
          message: 'Message',
        );

        expect(entry1, isNot(equals(entry2)));
      });

      test('should not be equal when message differs', () {
        final timestamp = DateTime(2025, 1, 15);
        final entry1 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message 1',
        );
        final entry2 = LogEntry(
          timestamp: timestamp,
          level: LogLevel.info,
          category: 'TEST',
          message: 'Message 2',
        );

        expect(entry1, isNot(equals(entry2)));
      });
    });

    group('toString()', () {
      test('should return readable string representation', () {
        final entry = LogEntry(
          timestamp: DateTime(2025, 1, 15),
          level: LogLevel.warning,
          category: 'NET',
          message: 'Connection timeout',
        );

        final str = entry.toString();
        expect(str, contains('LogEntry'));
        expect(str, contains('warning'));
        expect(str, contains('NET'));
        expect(str, contains('Connection timeout'));
      });
    });

    group('round-trip serialization', () {
      test('JSON serialization should be reversible', () {
        final original = TestHelpers.createTestLogEntry(
          level: LogLevel.error,
          context: {'key': 'value', 'number': 42},
          sessionId: 'test_session',
          sequenceNumber: 100,
        );

        final json = original.toJson();
        final deserialized = LogEntry.fromJson(json);

        expect(deserialized.level, original.level);
        expect(deserialized.category, original.category);
        expect(deserialized.message, original.message);
        expect(deserialized.context, original.context);
        expect(deserialized.sessionId, original.sessionId);
        expect(deserialized.sequenceNumber, original.sequenceNumber);
      });

      test('Compact JSON serialization should be reversible', () {
        final original = TestHelpers.createTestLogEntry(
          level: LogLevel.debug,
          context: {'test': true},
          sessionId: 'compact_session',
          sequenceNumber: 50,
        );

        final json = original.toCompactJson();
        final deserialized = LogEntry.fromCompactJson(json);

        expect(deserialized.level, original.level);
        expect(deserialized.category, original.category);
        expect(deserialized.message, original.message);
        expect(deserialized.context, original.context);
        expect(deserialized.sessionId, original.sessionId);
        expect(deserialized.sequenceNumber, original.sequenceNumber);
      });
    });
  });
}
