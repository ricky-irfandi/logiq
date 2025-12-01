import '../core/log_entry.dart';
import 'log_sink.dart';

/// Wrapper for custom sink functions.
class CustomSink extends LogSink {
  CustomSink({
    required this.onWrite,
    this.onClose,
  });

  final void Function(LogEntry entry) onWrite;
  final void Function()? onClose;

  @override
  void write(LogEntry entry) => onWrite(entry);

  @override
  void close() => onClose?.call();
}
