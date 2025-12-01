import '../core/log_entry.dart';

/// Callbacks for logging events.
class LogHooks {
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
