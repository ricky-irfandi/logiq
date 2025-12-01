import 'dart:developer' as developer;
import '../core/log_entry.dart';
import '../core/log_level.dart';
import 'log_sink.dart';

/// Sink that writes logs to the debug console with ANSI colors.
class ConsoleSink extends LogSink {
  const ConsoleSink({
    this.useColors = true,
    this.minLevel = LogLevel.verbose,
  });

  final bool useColors;
  final LogLevel minLevel;

  @override
  void write(LogEntry entry) {
    if (entry.level.value < minLevel.value) return;

    final message = _formatMessage(entry);
    developer.log(
      message,
      name: entry.category,
      level: _getLevelValue(entry.level),
    );
  }

  String _formatMessage(LogEntry entry) {
    final buffer = StringBuffer();

    if (useColors) {
      buffer.write(_getColorCode(entry.level));
    }

    buffer.write('[${entry.level.shortName}] ${entry.message}');

    if (entry.context != null && entry.context!.isNotEmpty) {
      buffer.write(' ${entry.context}');
    }

    if (useColors) {
      buffer.write(_resetCode);
    }

    return buffer.toString();
  }

  int _getLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 500;
      case LogLevel.debug:
        return 700;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.fatal:
        return 1200;
    }
  }

  String _getColorCode(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return _gray;
      case LogLevel.debug:
        return _blue;
      case LogLevel.info:
        return _green;
      case LogLevel.warning:
        return _yellow;
      case LogLevel.error:
        return _red;
      case LogLevel.fatal:
        return _magenta;
    }
  }

  // ANSI color codes
  static const String _gray = '\x1B[90m';
  static const String _blue = '\x1B[34m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _magenta = '\x1B[35m';
  static const String _resetCode = '\x1B[0m';
}
