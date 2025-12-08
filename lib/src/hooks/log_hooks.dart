import '../core/log_entry.dart';

/// Callbacks for observing logging lifecycle events.
///
/// Allows you to hook into various logging operations for monitoring,
/// analytics, or custom behavior.
///
/// ## Example
///
/// ```dart
/// LogHooks(
///   onLog: (entry) => print('Logged: ${entry.message}'),
///   onFlush: (count) => print('Flushed $count entries'),
///   onError: (error, stack) => crashlytics.recordError(error, stack),
/// )
/// ```
///
/// **Note**: Avoid logging within hook callbacks to prevent infinite recursion.
class LogHooks {
  /// Creates a hooks configuration with the specified callbacks.
  ///
  /// All callbacks are optional. Only provide the ones you need.
  const LogHooks({
    this.onLog,
    this.onFlush,
    this.onRotate,
    this.onError,
  });

  /// Called after a log entry is added to the buffer.
  final void Function(LogEntry entry)? onLog;

  /// Called after buffer is flushed to disk.
  /// Parameter is the number of entries flushed.
  final void Function(int count)? onFlush;

  /// Called after log file rotation.
  final void Function()? onRotate;

  /// Called when an error occurs during logging operations.
  /// Note: This is for internal errors, not for error-level logs.
  final void Function(Object error, StackTrace stackTrace)? onError;
}
