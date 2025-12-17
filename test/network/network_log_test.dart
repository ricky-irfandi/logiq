import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Network Logging', () {
    late TestLogSink testSink;
    late String logDirectory;

    setUp(() async {
      final tempDir = await TestHelpers.createTempDirectory();
      logDirectory = '${tempDir.path}/logs';

      testSink = TestLogSink();

      await Logiq.init(
        config: LogConfig(
          directory: logDirectory,
          minLevel: LogLevel.verbose,
          sinks: [testSink],
        ),
      );
    });

    tearDown(() async {
      try {
        await Logiq.dispose();
      } catch (_) {}
    });

    group('Logiq.network()', () {
      test('should log successful request', () {
        Logiq.network(
          method: 'GET',
          url: 'https://api.example.com/users',
          statusCode: 200,
          duration: const Duration(milliseconds: 234),
        );

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.category, 'HTTP');
        expect(testSink.entries.first.level, LogLevel.info);
        expect(testSink.entries.first.message, contains('GET'));
        expect(testSink.entries.first.message, contains('200'));
        expect(testSink.entries.first.context?['method'], 'GET');
        expect(testSink.entries.first.context?['statusCode'], 200);
        expect(testSink.entries.first.context?['durationMs'], 234);
      });

      test('should log error response as warning', () {
        Logiq.network(
          method: 'POST',
          url: 'https://api.example.com/users',
          statusCode: 404,
        );

        expect(testSink.entries.first.level, LogLevel.warning);
        expect(testSink.entries.first.context?['statusCode'], 404);
      });

      test('should log request failure as error', () {
        Logiq.network(
          method: 'GET',
          url: 'https://api.example.com/users',
          error: Exception('Connection refused'),
        );

        expect(testSink.entries.first.level, LogLevel.error);
        expect(testSink.entries.first.message, contains('failed'));
      });

      test('should use custom category', () {
        Logiq.network(
          method: 'GET',
          url: '/users',
          statusCode: 200,
          category: 'API',
        );

        expect(testSink.entries.first.category, 'API');
      });

      test('should include request and response bodies', () {
        Logiq.network(
          method: 'POST',
          url: '/users',
          statusCode: 201,
          requestBody: {'name': 'John'},
          responseBody: {'id': 123, 'name': 'John'},
        );

        expect(
            testSink.entries.first.context?['requestBody'], {'name': 'John'});
        expect(testSink.entries.first.context?['responseBody'],
            {'id': 123, 'name': 'John'});
      });
    });

    group('LogiqRequest', () {
      test('should create request with all fields', () {
        final request = LogiqRequest(
          method: 'POST',
          url: 'https://api.example.com/users',
          headers: {'Content-Type': 'application/json'},
          body: {'name': 'John'},
        );

        final context = request.toContext();
        expect(context['method'], 'POST');
        expect(context['url'], 'https://api.example.com/users');
        expect(context['headers'], {'Content-Type': 'application/json'});
        expect(context['body'], {'name': 'John'});
      });
    });

    group('LogiqResponse', () {
      test('should create response with all fields', () {
        final response = LogiqResponse(
          statusCode: 200,
          url: 'https://api.example.com/users',
          body: {'users': []},
          duration: const Duration(milliseconds: 234),
        );

        final context = response.toContext();
        expect(context['statusCode'], 200);
        expect(context['durationMs'], 234);
        expect(context['success'], true);
      });

      test('should identify success and error responses', () {
        expect(const LogiqResponse(statusCode: 200, url: '/').isSuccess, true);
        expect(const LogiqResponse(statusCode: 201, url: '/').isSuccess, true);
        expect(const LogiqResponse(statusCode: 400, url: '/').isError, true);
        expect(const LogiqResponse(statusCode: 500, url: '/').isError, true);
      });
    });

    group('Logiq.logRequest() and logResponse()', () {
      test('should log request with arrow prefix', () {
        Logiq.logRequest(const LogiqRequest(
          method: 'GET',
          url: '/users',
        ));

        expect(testSink.entries.first.message, contains('→'));
        expect(testSink.entries.first.message, contains('GET'));
      });

      test('should log response with arrow prefix', () {
        Logiq.logResponse(const LogiqResponse(
          statusCode: 200,
          url: '/users',
        ));

        expect(testSink.entries.first.message, contains('←'));
        expect(testSink.entries.first.message, contains('200'));
      });
    });
  });
}

/// Test implementation of LogSink that tracks calls.
class TestLogSink extends LogSink {
  final List<LogEntry> entries = [];

  @override
  void write(LogEntry entry) {
    entries.add(entry);
  }

  @override
  void close() {}
}
