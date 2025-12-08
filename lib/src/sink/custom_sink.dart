import '../core/log_entry.dart';
import 'log_sink.dart';

/// Wrapper for custom sink functions.
///
/// Allows you to provide custom callbacks for handling log entries
/// without creating a full [LogSink] subclass.
class CustomSink extends LogSink {
  /// Creates a custom sink with the provided callback functions.
  ///
  /// The [onWrite] callback is called for each log entry and is required.
  /// The optional [onClose] callback is called when the sink is disposed.
  CustomSink({
    required this.onWrite,
    this.onClose,
  });

  /// Callback invoked for each log entry written to this sink.
  final void Function(LogEntry entry) onWrite;

  /// Optional callback invoked when the sink is closed/disposed.
  ///
  /// Use this to clean up any resources held by your custom sink implementation.
  final void Function()? onClose;

  @override
  void write(LogEntry entry) => onWrite(entry);

  @override
  void close() => onClose?.call();
}
