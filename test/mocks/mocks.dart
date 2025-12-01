import 'package:logiq/logiq.dart';

/// Mock implementation of LogSink for testing.
class MockLogSink implements LogSink {
  final List<LogEntry> writtenEntries = [];

  @override
  void write(LogEntry entry) {
    writtenEntries.add(entry);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Mock implementation of ContextProvider for testing.
class MockContextProvider {
  Map<String, dynamic> contextData = {};

  Map<String, dynamic> call() => contextData;
}

/// Mock implementation of LogHooks for testing.
class MockLogHooks implements LogHooks {
  final List<LogEntry> loggedEntries = [];
  final List<int> flushCounts = [];
  final List<MapEntry<Object, StackTrace>> errors = [];

  @override
  void Function(LogEntry entry)? get onLog => (entry) {
        loggedEntries.add(entry);
      };

  @override
  void Function(int count)? get onFlush => (count) {
        flushCounts.add(count);
      };

  @override
  void Function()? get onRotate => null;

  @override
  void Function(Object error, StackTrace stackTrace)? get onError =>
      (error, stackTrace) {
        errors.add(MapEntry(error, stackTrace));
      };
}

/// Test implementation of LogSink that tracks calls.
class TestLogSink extends LogSink {
  TestLogSink({this.shouldThrow = false});

  final bool shouldThrow;
  final List<LogEntry> entries = [];
  int flushCount = 0;
  int closeCount = 0;

  @override
  void write(LogEntry entry) {
    if (shouldThrow) {
      throw Exception('Test sink error');
    }
    entries.add(entry);
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }

  @override
  Future<void> close() async {
    closeCount++;
  }
}

/// Test implementation of CustomSink.
class TestCustomSink extends CustomSink {
  TestCustomSink({required super.onWrite});
}
