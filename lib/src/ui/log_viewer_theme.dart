import 'package:flutter/material.dart';

/// Theme configuration for log viewer.
class LogViewerTheme {
  const LogViewerTheme({
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.textColor = const Color(0xFFD4D4D4),
    this.verboseColor = const Color(0xFF808080),
    this.debugColor = const Color(0xFF4FC3F7),
    this.infoColor = const Color(0xFF81C784),
    this.warningColor = const Color(0xFFFFB74D),
    this.errorColor = const Color(0xFFE57373),
    this.fatalColor = const Color(0xFFBA68C8),
    this.fontFamily = 'monospace',
    this.fontSize = 12.0,
    this.timestampColor = const Color(0xFF808080),
    this.categoryColor = const Color(0xFF9E9E9E),
  });

  final Color backgroundColor;
  final Color textColor;
  final Color verboseColor;
  final Color debugColor;
  final Color infoColor;
  final Color warningColor;
  final Color errorColor;
  final Color fatalColor;
  final String fontFamily;
  final double fontSize;
  final Color timestampColor;
  final Color categoryColor;

  /// Get color for log level.
  Color colorForLevel(int levelValue) {
    switch (levelValue) {
      case 0:
        return verboseColor;
      case 1:
        return debugColor;
      case 2:
        return infoColor;
      case 3:
        return warningColor;
      case 4:
        return errorColor;
      case 5:
        return fatalColor;
      default:
        return textColor;
    }
  }
}
