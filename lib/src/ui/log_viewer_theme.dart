import 'package:flutter/material.dart';

/// Apple-inspired theme for the log viewer.
/// Uses refined colors with subtle gradients and proper contrast.
class LogViewerTheme {
  const LogViewerTheme({
    this.backgroundColor = const Color(0xFF000000),
    this.surfaceColor = const Color(0xFF1C1C1E),
    this.elevatedSurfaceColor = const Color(0xFF2C2C2E),
    this.textColor = const Color(0xFFF2F2F7),
    this.secondaryTextColor = const Color(0xFF8E8E93),
    this.tertiaryTextColor = const Color(0xFF636366),
    this.verboseColor = const Color(0xFF636366),
    this.debugColor = const Color(0xFF5AC8FA),
    this.infoColor = const Color(0xFF34C759),
    this.warningColor = const Color(0xFFFF9F0A),
    this.errorColor = const Color(0xFFFF3B30),
    this.fatalColor = const Color(0xFFAF52DE),
    this.accentColor = const Color(0xFF007AFF),
    this.separatorColor = const Color(0xFF38383A),
    this.timestampColor = const Color(0xFF8E8E93),
    this.categoryColor = const Color(0xFFAEAEB2),
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color elevatedSurfaceColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color tertiaryTextColor;
  final Color verboseColor;
  final Color debugColor;
  final Color infoColor;
  final Color warningColor;
  final Color errorColor;
  final Color fatalColor;
  final Color accentColor;
  final Color separatorColor;
  final Color timestampColor;
  final Color categoryColor;

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

  /// Light theme with iOS-inspired colors
  static const light = LogViewerTheme(
    backgroundColor: Color(0xFFFFFFFF),
    surfaceColor: Color(0xFFF2F2F7),
    elevatedSurfaceColor: Color(0xFFE5E5EA),
    textColor: Color(0xFF000000),
    secondaryTextColor: Color(0xFF6C6C70),
    tertiaryTextColor: Color(0xFF8E8E93),
    verboseColor: Color(0xFF8E8E93),
    debugColor: Color(0xFF0A84FF),
    infoColor: Color(0xFF30D158),
    warningColor: Color(0xFFFF9F0A),
    errorColor: Color(0xFFFF3B30),
    fatalColor: Color(0xFFBF5AF2),
    accentColor: Color(0xFF007AFF),
    separatorColor: Color(0xFFC6C6C8),
    timestampColor: Color(0xFF6C6C70),
    categoryColor: Color(0xFF8E8E93),
  );

  /// Dark theme with iOS-inspired colors (default)
  static const dark = LogViewerTheme();
}
