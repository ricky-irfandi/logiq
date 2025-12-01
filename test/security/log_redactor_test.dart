import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/src/security/log_redactor.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LogRedactor', () {
    group('initialization', () {
      test('should accept empty pattern list', () {
        expect(() => LogRedactor([]), returnsNormally);
      });

      test('should accept single pattern', () {
        expect(() => LogRedactor([RedactionPattern.email]), returnsNormally);
      });

      test('should accept multiple patterns', () {
        expect(
          () => LogRedactor([
            RedactionPattern.email,
            RedactionPattern.phone,
            RedactionPattern.creditCard,
          ]),
          returnsNormally,
        );
      });
    });

    group('redact() - message redaction', () {
      test('should not redact when no patterns', () {
        final redactor = LogRedactor([]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Email: user@example.com Phone: 081234567890',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, entry.message);
      });

      test('should redact email addresses', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'User email is test@example.com',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'User email is [EMAIL_REDACTED]');
        expect(redacted.message, isNot(contains('test@example.com')));
      });

      test('should redact multiple email addresses', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Emails: user1@test.com and user2@example.org',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[EMAIL_REDACTED]'));
        expect(redacted.message, isNot(contains('user1@test.com')));
        expect(redacted.message, isNot(contains('user2@example.org')));
      });

      test('should redact Indonesian phone numbers', () {
        final redactor = LogRedactor([RedactionPattern.phoneIndonesia]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Contact: 081234567890',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Contact: [PHONE_REDACTED]');
        expect(redacted.message, isNot(contains('081234567890')));
      });

      test('should redact Indonesian phone with +62 prefix', () {
        final redactor = LogRedactor([RedactionPattern.phoneIndonesia]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'WhatsApp: +628123456789',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[PHONE_REDACTED]'));
        expect(redacted.message, isNot(contains('+628123456789')));
      });

      test('should redact credit card numbers', () {
        final redactor = LogRedactor([RedactionPattern.creditCard]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Card: 4532-1234-5678-9010',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Card: [CARD_REDACTED]');
        expect(redacted.message, isNot(contains('4532')));
      });

      test('should redact credit card without hyphens', () {
        final redactor = LogRedactor([RedactionPattern.creditCard]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Card: 4532123456789010',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[CARD_REDACTED]'));
      });

      test('should redact IP addresses', () {
        final redactor = LogRedactor([RedactionPattern.ipAddress]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Request from 192.168.1.100',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Request from [IP_REDACTED]');
        expect(redacted.message, isNot(contains('192.168.1.100')));
      });

      test('should redact JWT tokens', () {
        final redactor = LogRedactor([RedactionPattern.jwtToken]);
        final entry = TestHelpers.createTestLogEntry(
          message:
              'Token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Token: [TOKEN_REDACTED]');
        expect(redacted.message, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      });

      test('should redact Indonesian vehicle plates (nopol)', () {
        final redactor = LogRedactor([RedactionPattern.nopolIndonesia]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Vehicle: B 1234 XYZ',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Vehicle: [NOPOL_REDACTED]');
      });
    });

    group('redact() - context redaction', () {
      test('should not redact context when no patterns', () {
        final redactor = LogRedactor([]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'User login',
          context: {'email': 'user@example.com'},
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['email'], 'user@example.com');
      });

      test('should redact strings in context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'User login',
          context: {'email': 'user@example.com', 'name': 'John'},
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['name'], 'John'); // Not sensitive
      });

      test('should redact nested maps in context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'User data',
          context: {
            'user': {
              'email': 'user@example.com',
              'profile': {
                'contact': 'admin@test.com',
              },
            },
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['user']['email'], '[EMAIL_REDACTED]');
        expect(
          redacted.context!['user']['profile']['contact'],
          '[EMAIL_REDACTED]',
        );
      });

      test('should redact strings in lists', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Email list',
          context: {
            'emails': ['user1@test.com', 'user2@example.org'],
          },
        );

        final redacted = redactor.redact(entry);

        final emails = redacted.context!['emails'] as List;
        expect(emails[0], '[EMAIL_REDACTED]');
        expect(emails[1], '[EMAIL_REDACTED]');
      });

      test('should handle nested lists and maps', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Complex data',
          context: {
            'users': [
              {'email': 'user1@test.com', 'id': 1},
              {'email': 'user2@test.com', 'id': 2},
            ],
          },
        );

        final redacted = redactor.redact(entry);

        final users = redacted.context!['users'] as List;
        expect(users[0]['email'], '[EMAIL_REDACTED]');
        expect(users[0]['id'], 1); // Non-string preserved
        expect(users[1]['email'], '[EMAIL_REDACTED]');
      });

      test('should preserve non-string values in context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Mixed types',
          context: {
            'email': 'user@example.com',
            'count': 42,
            'active': true,
            'rating': 4.5,
            'data': null,
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['count'], 42);
        expect(redacted.context!['active'], true);
        expect(redacted.context!['rating'], 4.5);
        expect(redacted.context!['data'], isNull);
      });

      test('should handle null context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'user@example.com',
          context: null,
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context, isNull);
        expect(redacted.message, '[EMAIL_REDACTED]');
      });

      test('should handle empty context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Test',
          context: {},
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context, isEmpty);
      });
    });

    group('redact() - multiple patterns', () {
      test('should apply multiple patterns to message', () {
        final redactor = LogRedactor([
          RedactionPattern.email,
          RedactionPattern.phoneIndonesia,
          RedactionPattern.creditCard,
        ]);
        final entry = TestHelpers.createTestLogEntry(
          message:
              'User: user@test.com, Phone: 081234567890, Card: 4532-1234-5678-9010',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[EMAIL_REDACTED]'));
        expect(redacted.message, contains('[PHONE_REDACTED]'));
        expect(redacted.message, contains('[CARD_REDACTED]'));
        expect(redacted.message, isNot(contains('user@test.com')));
        expect(redacted.message, isNot(contains('081234567890')));
        expect(redacted.message, isNot(contains('4532')));
      });

      test('should apply multiple patterns to context', () {
        final redactor = LogRedactor([
          RedactionPattern.email,
          RedactionPattern.ipAddress,
        ]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Request',
          context: {
            'user': 'admin@example.com',
            'ip': '192.168.1.1',
            'port': 8080,
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['user'], '[EMAIL_REDACTED]');
        expect(redacted.context!['ip'], '[IP_REDACTED]');
        expect(redacted.context!['port'], 8080);
      });

      test('should apply all default patterns', () {
        final redactor = LogRedactor(RedactionPattern.defaults);
        final entry = TestHelpers.createTestLogEntry(
          message:
              'Email: user@test.com, Phone: 555-1234, Card: 4532-1234-5678-9010',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[EMAIL_REDACTED]'));
        expect(redacted.message, isNot(contains('user@test.com')));
      });
    });

    group('redactString()', () {
      test('should redact sensitive data from plain string', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        const text = 'Contact us at support@example.com';

        final redacted = redactor.redactString(text);

        expect(redacted, 'Contact us at [EMAIL_REDACTED]');
      });

      test('should handle string without sensitive data', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        const text = 'This is a normal message';

        final redacted = redactor.redactString(text);

        expect(redacted, text);
      });

      test('should apply multiple patterns to string', () {
        final redactor = LogRedactor([
          RedactionPattern.email,
          RedactionPattern.phoneIndonesia,
        ]);
        const text = 'Email: user@test.com, Phone: +628123456789';

        final redacted = redactor.redactString(text);

        expect(redacted, contains('[EMAIL_REDACTED]'));
        expect(redacted, contains('[PHONE_REDACTED]'));
      });
    });

    group('custom patterns', () {
      test('should apply custom redaction pattern', () {
        final customPattern = RedactionPattern(
          name: 'user_id',
          pattern: RegExp(r'user_\d+'),
          replacement: '[USER_ID]',
        );
        final redactor = LogRedactor([customPattern]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Processing request for user_12345',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Processing request for [USER_ID]');
      });

      test('should apply multiple custom patterns', () {
        final patterns = [
          RedactionPattern(
            name: 'order_id',
            pattern: RegExp(r'ORD-\d{6}'),
            replacement: '[ORDER]',
          ),
          RedactionPattern(
            name: 'transaction_id',
            pattern: RegExp(r'TXN-[A-Z0-9]{8}'),
            replacement: '[TXN]',
          ),
        ];
        final redactor = LogRedactor(patterns);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Order ORD-123456 processed with TXN-ABC12345',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Order [ORDER] processed with [TXN]');
      });

      test('should support custom replacement text', () {
        final pattern = RedactionPattern(
          name: 'api_key',
          pattern: RegExp(r'api_key=[a-z0-9]{32}'),
          replacement: 'api_key=***HIDDEN***',
        );
        final redactor = LogRedactor([pattern]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Request with api_key=abc123def456ghi789jkl012mno345pq',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, 'Request with api_key=***HIDDEN***');
      });
    });

    group('edge cases', () {
      test('should handle empty message', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(message: '');

        final redacted = redactor.redact(entry);

        expect(redacted.message, '');
      });

      test('should handle very long message', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final longMessage = 'Text ' * 1000 + 'user@example.com';
        final entry = TestHelpers.createTestLogEntry(message: longMessage);

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[EMAIL_REDACTED]'));
        expect(redacted.message, isNot(contains('user@example.com')));
      });

      test('should handle unicode characters', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: '用户邮箱: user@example.com 🎉',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, '用户邮箱: [EMAIL_REDACTED] 🎉');
      });

      test('should handle special regex characters in text', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message:
              r'Email pattern: [a-z]+@[a-z]+\.[a-z]+ actual: user@test.com',
        );

        final redacted = redactor.redact(entry);

        expect(redacted.message, contains('[EMAIL_REDACTED]'));
      });

      test('should preserve log entry metadata', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final original = LogEntry(
          timestamp: DateTime.utc(2025, 1, 15, 10, 30, 45),
          level: LogLevel.warning,
          category: 'AUTH',
          message: 'Login attempt from user@example.com',
          context: {'ip': '192.168.1.1'},
          sessionId: 'sess_123',
          sequenceNumber: 42,
        );

        final redacted = redactor.redact(original);

        expect(redacted.timestamp, original.timestamp);
        expect(redacted.level, original.level);
        expect(redacted.category, original.category);
        expect(redacted.sessionId, original.sessionId);
        expect(redacted.sequenceNumber, original.sequenceNumber);
        expect(redacted.message, isNot(equals(original.message)));
      });

      test('should handle deeply nested context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Deep data',
          context: {
            'level1': {
              'level2': {
                'level3': {
                  'level4': {
                    'level5': {
                      'email': 'deep@example.com',
                    },
                  },
                },
              },
            },
          },
        );

        final redacted = redactor.redact(entry);

        expect(
          redacted.context!['level1']['level2']['level3']['level4']['level5']
              ['email'],
          '[EMAIL_REDACTED]',
        );
      });

      test('should handle circular-like references in context', () {
        final redactor = LogRedactor([RedactionPattern.email]);
        final entry = TestHelpers.createTestLogEntry(
          message: 'Test',
          context: {
            'a': {
              'email': 'user@test.com',
              'b': {
                'email': 'admin@test.com',
                'c': {
                  'email': 'support@test.com',
                },
              },
            },
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['a']['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['a']['b']['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['a']['b']['c']['email'], '[EMAIL_REDACTED]');
      });
    });

    group('real-world scenarios', () {
      test('should redact user registration logs', () {
        final redactor = LogRedactor([
          RedactionPattern.email,
          RedactionPattern.phoneIndonesia,
        ]);
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          category: 'AUTH',
          message: 'User registration successful',
          context: {
            'email': 'newuser@example.com',
            'phone': '+628123456789',
            'username': 'john_doe',
            'userId': 12345,
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['phone'], '[PHONE_REDACTED]');
        expect(redacted.context!['username'], 'john_doe');
        expect(redacted.context!['userId'], 12345);
      });

      test('should redact payment processing logs', () {
        final redactor = LogRedactor([
          RedactionPattern.creditCard,
          RedactionPattern.email,
        ]);
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          category: 'PAYMENT',
          message: 'Payment processed for card ending 9010',
          context: {
            'cardNumber': '4532-1234-5678-9010',
            'email': 'customer@example.com',
            'amount': 150000,
            'currency': 'IDR',
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['cardNumber'], '[CARD_REDACTED]');
        expect(redacted.context!['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['amount'], 150000);
        expect(redacted.context!['currency'], 'IDR');
      });

      test('should redact API request logs', () {
        final redactor = LogRedactor([
          RedactionPattern.jwtToken,
          RedactionPattern.ipAddress,
        ]);
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.debug,
          category: 'API',
          message: 'Incoming API request',
          context: {
            'path': '/api/users',
            'method': 'POST',
            'ip': '192.168.1.100',
            'userAgent': 'Mozilla/5.0',
            'authorization':
                'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U',
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['ip'], '[IP_REDACTED]');
        expect(redacted.context!['authorization'], 'Bearer [TOKEN_REDACTED]');
        expect(redacted.context!['path'], '/api/users');
      });

      test('should redact vehicle tracking logs', () {
        final redactor = LogRedactor([RedactionPattern.nopolIndonesia]);
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          category: 'TRACKING',
          message: 'Vehicle entered zone',
          context: {
            'plate': 'B 1234 XYZ',
            'zone': 'Central Jakarta',
            'speed': 60,
          },
        );

        final redacted = redactor.redact(entry);

        expect(redacted.context!['plate'], '[NOPOL_REDACTED]');
        expect(redacted.context!['zone'], 'Central Jakarta');
        expect(redacted.context!['speed'], 60);
      });

      test('should handle comprehensive PII in error logs', () {
        final redactor = LogRedactor(RedactionPattern.defaults);
        final entry = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          category: 'ERROR',
          message: 'Failed to process transaction',
          context: {
            'error':
                'Validation failed for user@example.com with card 4532123456789010',
            'user': {
              'email': 'user@example.com',
              'phone': '555-1234',
            },
            'request': {
              'ip': '10.0.0.1',
              'card': '4532-1234-5678-9010',
            },
          },
        );

        final redacted = redactor.redact(entry);

        // All sensitive data should be redacted
        expect(redacted.context!['error'], contains('[EMAIL_REDACTED]'));
        expect(redacted.context!['error'], contains('[CARD_REDACTED]'));
        expect(redacted.context!['user']['email'], '[EMAIL_REDACTED]');
        expect(redacted.context!['request']['ip'], '[IP_REDACTED]');
        expect(redacted.context!['request']['card'], '[CARD_REDACTED]');
      });
    });
  });
}
