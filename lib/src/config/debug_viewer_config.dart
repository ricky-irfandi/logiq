import 'package:flutter/foundation.dart';
import '../ui/log_viewer_theme.dart';
import 'debug_tab.dart';

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
    this.tabs = const [],
  });

  /// Whether debug viewer is enabled.
  final bool enabled;

  /// Theme for log viewer.
  final LogViewerTheme theme;

  /// Whether to show floating debug button.
  final bool showFloatingButton;

  /// Position of floating button.
  final FloatingButtonPosition floatingButtonPosition;

  /// Custom tabs for organizing logs by category.
  ///
  /// When empty (default), shows all logs in a single view.
  /// When configured, displays a tab bar with custom tabs plus an "All" tab.
  ///
  /// Example:
  /// ```dart
  /// tabs: [
  ///   DebugTab(name: 'Network', categories: ['API', 'HTTP']),
  ///   DebugTab(name: 'Database', categories: ['DB', 'SQL']),
  /// ]
  /// ```
  final List<DebugTab> tabs;

  /// Creates a copy of this configuration with the specified fields replaced.
  DebugViewerConfig copyWith({
    bool? enabled,
    LogViewerTheme? theme,
    bool? showFloatingButton,
    FloatingButtonPosition? floatingButtonPosition,
    List<DebugTab>? tabs,
  }) {
    return DebugViewerConfig(
      enabled: enabled ?? this.enabled,
      theme: theme ?? this.theme,
      showFloatingButton: showFloatingButton ?? this.showFloatingButton,
      tabs: tabs ?? this.tabs,
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
