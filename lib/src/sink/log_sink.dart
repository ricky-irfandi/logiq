import '../core/log_entry.dart';

/// Base class for log output sinks.
///
/// A sink receives log entries and outputs them to a destination
/// (console, file, network, etc.). Implement this class to create
/// custom log destinations.
///
/// ## Built-in Sinks
///
/// - [ConsoleSink] - Outputs to debug console with ANSI colors
/// - [CustomSink] - Wrapper for custom callback functions
///
/// ## Custom Sink Example
///
/// ```dart
/// class NetworkSink extends LogSink {
///   @override
///   void write(LogEntry entry) {
///     httpClient.post('/logs', body: entry.toJson());
///   }
///
///   @override
///   void close() {
///     httpClient.close();
///   }
/// }
/// ```
abstract class LogSink {
  /// Creates a log sink.
  const LogSink();

  /// Writes a log entry to this sink.
  ///
  /// Called for each log entry that passes the minimum level filter.
  /// Implementations should handle errors gracefully without throwing.
  void write(LogEntry entry);

  /// Closes and cleans up resources used by this sink.
  ///
  /// Called when the logging system is disposed. Override to release
  /// any resources (connections, file handles, etc.).
  void close() {}
}
