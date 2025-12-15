import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogiqNavigatorObserver', () {
    late LogiqNavigatorObserver observer;
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

      observer = LogiqNavigatorObserver();
    });

    tearDown(() async {
      try {
        await Logiq.dispose();
      } catch (_) {}
    });

    // Helper to create a mock route
    Route<dynamic> createMockRoute({String? name, Object? arguments}) {
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: name, arguments: arguments),
        builder: (_) => const SizedBox(),
      );
    }

    group('didPush', () {
      test('should log push navigation event', () {
        final route = createMockRoute(name: '/home');
        final previousRoute = createMockRoute(name: '/login');

        observer.didPush(route, previousRoute);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.category, 'NAV');
        expect(testSink.entries.first.message, contains('Navigated to /home'));
        expect(testSink.entries.first.message, contains('from /login'));
        expect(testSink.entries.first.context?['action'], 'push');
        expect(testSink.entries.first.context?['route'], '/home');
        expect(testSink.entries.first.context?['previousRoute'], '/login');
      });

      test('should log push without previous route', () {
        final route = createMockRoute(name: '/home');

        observer.didPush(route, null);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.message, contains('Navigated to /home'));
        expect(testSink.entries.first.context?['action'], 'push');
        expect(testSink.entries.first.context?['route'], '/home');
      });

      test('should include route type', () {
        final route = createMockRoute(name: '/home');

        observer.didPush(route, null);

        expect(
          testSink.entries.first.context?['routeType'],
          contains('MaterialPageRoute'),
        );
      });

      test('should include route arguments when present', () {
        final route = createMockRoute(
          name: '/details',
          arguments: {'id': 123, 'name': 'Test'},
        );

        observer.didPush(route, null);

        expect(testSink.entries.first.context?['arguments'], isNotNull);
        expect(testSink.entries.first.context?['arguments']['id'], 123);
      });
    });

    group('didPop', () {
      test('should log pop navigation event', () {
        final route = createMockRoute(name: '/details');
        final previousRoute = createMockRoute(name: '/home');

        observer.didPop(route, previousRoute);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.message, contains('Popped /details'));
        expect(testSink.entries.first.message, contains('returning to /home'));
        expect(testSink.entries.first.context?['action'], 'pop');
        expect(testSink.entries.first.context?['route'], '/details');
        expect(testSink.entries.first.context?['previousRoute'], '/home');
      });
    });

    group('didReplace', () {
      test('should log replace navigation event', () {
        final newRoute = createMockRoute(name: '/success');
        final oldRoute = createMockRoute(name: '/loading');

        observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.message, contains('Replaced /loading'));
        expect(testSink.entries.first.message, contains('with /success'));
        expect(testSink.entries.first.context?['action'], 'replace');
        expect(testSink.entries.first.context?['newRoute'], '/success');
        expect(testSink.entries.first.context?['oldRoute'], '/loading');
      });
    });

    group('didRemove', () {
      test('should log remove navigation event', () {
        final route = createMockRoute(name: '/modal');

        observer.didRemove(route, null);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.message, contains('Removed /modal'));
        expect(testSink.entries.first.context?['action'], 'remove');
        expect(testSink.entries.first.context?['route'], '/modal');
      });
    });

    group('route name extraction', () {
      test('should fallback to route type when no name', () {
        final route = createMockRoute(name: null);

        observer.didPush(route, null);

        expect(
          testSink.entries.first.context?['route'],
          contains('MaterialPageRoute'),
        );
      });

      test('should handle null routes safely', () {
        observer.didReplace(newRoute: null, oldRoute: null);

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.context?['newRoute'], 'null');
        expect(testSink.entries.first.context?['oldRoute'], 'null');
      });
    });

    group('configuration', () {
      test('should respect enabled flag', () {
        final disabledObserver = LogiqNavigatorObserver(enabled: false);
        final route = createMockRoute(name: '/home');

        disabledObserver.didPush(route, null);

        expect(testSink.entries, isEmpty);
      });

      test('should use custom category', () {
        final customObserver = LogiqNavigatorObserver(category: 'NAVIGATION');
        final route = createMockRoute(name: '/home');

        customObserver.didPush(route, null);

        expect(testSink.entries.first.category, 'NAVIGATION');
      });

      test('should use custom log level', () {
        final debugObserver = LogiqNavigatorObserver(logLevel: LogLevel.debug);
        final route = createMockRoute(name: '/home');

        debugObserver.didPush(route, null);

        expect(testSink.entries.first.level, LogLevel.debug);
      });

      test('should not include arguments when disabled', () {
        final noArgsObserver = LogiqNavigatorObserver(logRouteArguments: false);
        final route = createMockRoute(
          name: '/details',
          arguments: {'id': 123},
        );

        noArgsObserver.didPush(route, null);

        expect(testSink.entries.first.context?['arguments'], isNull);
      });
    });

    group('Logiq.navigationObserver', () {
      test('should return a LogiqNavigatorObserver instance', () {
        expect(Logiq.navigationObserver, isA<LogiqNavigatorObserver>());
      });

      test('should return the same instance', () {
        final observer1 = Logiq.navigationObserver;
        final observer2 = Logiq.navigationObserver;

        expect(identical(observer1, observer2), isTrue);
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
