import '../core/log_entry.dart';
import 'redaction_pattern.dart';

/// Handles PII redaction in log entries.
class LogRedactor {
  LogRedactor(this.patterns);

  final List<RedactionPattern> patterns;

  /// Redact sensitive data from a log entry.
  LogEntry redact(LogEntry entry) {
    if (patterns.isEmpty) return entry;

    return entry.copyWith(
      message: _redactString(entry.message),
      context: entry.context != null ? _redactMap(entry.context!) : null,
    );
  }

  /// Redact sensitive data from formatted string.
  String redactString(String text) {
    return _redactString(text);
  }

  String _redactString(String text) {
    var result = text;
    for (final pattern in patterns) {
      result = pattern.apply(result);
    }
    return result;
  }

  Map<String, dynamic> _redactMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is String) {
        return MapEntry(key, _redactString(value));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _redactMap(value));
      } else if (value is List) {
        return MapEntry(key, _redactList(value));
      }
      return MapEntry(key, value);
    });
  }

  List<dynamic> _redactList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return _redactString(item);
      } else if (item is Map<String, dynamic>) {
        return _redactMap(item);
      } else if (item is List) {
        return _redactList(item);
      }
      return item;
    }).toList();
  }
}
