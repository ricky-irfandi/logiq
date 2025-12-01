/// Log severity levels in ascending order of importance.
enum LogLevel {
  /// Most detailed logging, for tracing program flow.
  verbose(0, 'VERBOSE', 'V'),

  /// Debugging information for development.
  debug(1, 'DEBUG', 'D'),

  /// General informational messages.
  info(2, 'INFO', 'I'),

  /// Warning conditions that might cause issues.
  warning(3, 'WARNING', 'W'),

  /// Error conditions that should be addressed.
  error(4, 'ERROR', 'E'),

  /// Critical failures requiring immediate attention.
  fatal(5, 'FATAL', 'F');

  const LogLevel(this.value, this.displayName, this.shortName);

  /// Numeric value for comparison.
  final int value;

  /// Full name for display.
  final String displayName;

  /// Short name for compact formats.
  final String shortName;

  /// Check if this level is at or above [other].
  bool isAtLeast(LogLevel other) => value >= other.value;

  /// Parse from string (case-insensitive).
  static LogLevel? tryParse(String value) {
    final lower = value.toLowerCase();
    for (final level in values) {
      if (level.name.toLowerCase() == lower ||
          level.displayName.toLowerCase() == lower ||
          level.shortName.toLowerCase() == lower) {
        return level;
      }
    }
    return null;
  }

  /// Parse from numeric value.
  static LogLevel? fromValue(int value) {
    for (final level in values) {
      if (level.value == value) return level;
    }
    return null;
  }
}
