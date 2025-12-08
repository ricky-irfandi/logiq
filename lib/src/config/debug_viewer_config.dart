import 'package:flutter/foundation.dart';
import '../ui/log_viewer_theme.dart';

/// Configuration for the built-in debug log viewer UI.
///
/// Controls visibility and appearance of the log viewer screen
/// and floating debug button.
///
/// ## Example
///
/// ```dart
/// // Enable only in debug mode (default)
/// DebugViewerConfig()
///
/// // Always enabled with custom theme
/// DebugViewerConfig(
///   enabled: true,
///   theme: LogViewerTheme(backgroundColor: Colors.black),
///   floatingButtonPosition: FloatingButtonPosition.bottomLeft,
/// )
/// ```
class DebugViewerConfig {
  /// Creates a debug viewer configuration with the specified options.
  ///
  /// By default, enabled only in debug mode (`kDebugMode`).
  const DebugViewerConfig({
    this.enabled = kDebugMode,
    this.theme = const LogViewerTheme(),
    this.showFloatingButton = true,
    this.floatingButtonPosition = FloatingButtonPosition.bottomRight,
  });

  /// Whether debug viewer is enabled.
  final bool enabled;

  /// Theme for log viewer.
  final LogViewerTheme theme;

  /// Whether to show floating debug button.
  final bool showFloatingButton;

  /// Position of floating button.
  final FloatingButtonPosition floatingButtonPosition;

  /// Creates a copy of this configuration with the specified fields replaced.
  DebugViewerConfig copyWith({
    bool? enabled,
    LogViewerTheme? theme,
    bool? showFloatingButton,
    FloatingButtonPosition? floatingButtonPosition,
  }) {
    return DebugViewerConfig(
      enabled: enabled ?? this.enabled,
      theme: theme ?? this.theme,
      showFloatingButton: showFloatingButton ?? this.showFloatingButton,
      floatingButtonPosition:
          floatingButtonPosition ?? this.floatingButtonPosition,
    );
  }
}

/// Position options for the floating debug button overlay.
enum FloatingButtonPosition {
  /// Top-left corner of the screen.
  topLeft,

  /// Top-right corner of the screen.
  topRight,

  /// Bottom-left corner of the screen.
  bottomLeft,

  /// Bottom-right corner of the screen (default).
  bottomRight,
}
