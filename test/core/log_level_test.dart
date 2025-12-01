import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';

void main() {
  group('LogLevel', () {
    group('enum values', () {
      test('should have correct numeric values', () {
        expect(LogLevel.verbose.value, 0);
        expect(LogLevel.debug.value, 1);
        expect(LogLevel.info.value, 2);
        expect(LogLevel.warning.value, 3);
        expect(LogLevel.error.value, 4);
        expect(LogLevel.fatal.value, 5);
      });

      test('should have correct names', () {
        expect(LogLevel.verbose.name, 'verbose');
        expect(LogLevel.debug.name, 'debug');
        expect(LogLevel.info.name, 'info');
        expect(LogLevel.warning.name, 'warning');
        expect(LogLevel.error.name, 'error');
        expect(LogLevel.fatal.name, 'fatal');
      });

      test('should have correct short names', () {
        expect(LogLevel.verbose.shortName, 'V');
        expect(LogLevel.debug.shortName, 'D');
        expect(LogLevel.info.shortName, 'I');
        expect(LogLevel.warning.shortName, 'W');
        expect(LogLevel.error.shortName, 'E');
        expect(LogLevel.fatal.shortName, 'F');
      });

      test('should be in ascending order of severity', () {
        expect(LogLevel.verbose.value < LogLevel.debug.value, isTrue);
        expect(LogLevel.debug.value < LogLevel.info.value, isTrue);
        expect(LogLevel.info.value < LogLevel.warning.value, isTrue);
        expect(LogLevel.warning.value < LogLevel.error.value, isTrue);
        expect(LogLevel.error.value < LogLevel.fatal.value, isTrue);
      });
    });

    group('isAtLeast()', () {
      test('should return true when level is at or above threshold', () {
        expect(LogLevel.error.isAtLeast(LogLevel.info), isTrue);
        expect(LogLevel.error.isAtLeast(LogLevel.error), isTrue);
        expect(LogLevel.fatal.isAtLeast(LogLevel.warning), isTrue);
      });

      test('should return false when level is below threshold', () {
        expect(LogLevel.info.isAtLeast(LogLevel.error), isFalse);
        expect(LogLevel.debug.isAtLeast(LogLevel.warning), isFalse);
        expect(LogLevel.verbose.isAtLeast(LogLevel.info), isFalse);
      });

      test('should work for all level combinations', () {
        for (final level in LogLevel.values) {
          for (final threshold in LogLevel.values) {
            final expected = level.value >= threshold.value;
            expect(
              level.isAtLeast(threshold),
              expected,
              reason: '$level.isAtLeast($threshold) should be $expected',
            );
          }
        }
      });
    });

    group('tryParse()', () {
      test('should parse valid level names (case-insensitive)', () {
        expect(LogLevel.tryParse('verbose'), LogLevel.verbose);
        expect(LogLevel.tryParse('VERBOSE'), LogLevel.verbose);
        expect(LogLevel.tryParse('Verbose'), LogLevel.verbose);
        expect(LogLevel.tryParse('debug'), LogLevel.debug);
        expect(LogLevel.tryParse('INFO'), LogLevel.info);
        expect(LogLevel.tryParse('warning'), LogLevel.warning);
        expect(LogLevel.tryParse('ERROR'), LogLevel.error);
        expect(LogLevel.tryParse('Fatal'), LogLevel.fatal);
      });

      test('should parse valid short names (case-insensitive)', () {
        expect(LogLevel.tryParse('V'), LogLevel.verbose);
        expect(LogLevel.tryParse('v'), LogLevel.verbose);
        expect(LogLevel.tryParse('D'), LogLevel.debug);
        expect(LogLevel.tryParse('d'), LogLevel.debug);
        expect(LogLevel.tryParse('I'), LogLevel.info);
        expect(LogLevel.tryParse('W'), LogLevel.warning);
        expect(LogLevel.tryParse('E'), LogLevel.error);
        expect(LogLevel.tryParse('F'), LogLevel.fatal);
      });

      test('should return null for invalid input', () {
        expect(LogLevel.tryParse('invalid'), isNull);
        expect(LogLevel.tryParse(''), isNull);
        expect(LogLevel.tryParse('trace'), isNull);
        expect(LogLevel.tryParse('critical'), isNull);
        expect(LogLevel.tryParse('123'), isNull);
      });

      test('should handle whitespace', () {
        expect(LogLevel.tryParse(' info '), isNull); // Whitespace not trimmed
        expect(LogLevel.tryParse('info'), LogLevel.info);
      });
    });

    group('fromValue()', () {
      test('should return correct level for valid values', () {
        expect(LogLevel.fromValue(0), LogLevel.verbose);
        expect(LogLevel.fromValue(1), LogLevel.debug);
        expect(LogLevel.fromValue(2), LogLevel.info);
        expect(LogLevel.fromValue(3), LogLevel.warning);
        expect(LogLevel.fromValue(4), LogLevel.error);
        expect(LogLevel.fromValue(5), LogLevel.fatal);
      });

      test('should return null for invalid values', () {
        expect(LogLevel.fromValue(-1), isNull);
        expect(LogLevel.fromValue(6), isNull);
        expect(LogLevel.fromValue(100), isNull);
      });
    });

    group('edge cases', () {
      test('should have 6 total levels', () {
        expect(LogLevel.values.length, 6);
      });

      test('all levels should have unique values', () {
        final values = LogLevel.values.map((l) => l.value).toSet();
        expect(values.length, LogLevel.values.length);
      });

      test('all levels should have unique names', () {
        final names = LogLevel.values.map((l) => l.name).toSet();
        expect(names.length, LogLevel.values.length);
      });

      test('all levels should have unique short names', () {
        final shortNames = LogLevel.values.map((l) => l.shortName).toSet();
        expect(shortNames.length, LogLevel.values.length);
      });
    });
  });
}
