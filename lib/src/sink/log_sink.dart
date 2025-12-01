import '../core/log_entry.dart';

/// Base class for log output sinks.
abstract class LogSink {
  const LogSink();

  /// Write a log entry to this sink.
  void write(LogEntry entry);

  /// Close/cleanup this sink.
  void close() {}
}
