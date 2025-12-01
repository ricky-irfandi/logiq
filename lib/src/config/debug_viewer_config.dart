import 'package:flutter/foundation.dart';
import '../ui/log_viewer_theme.dart';

/// Configuration for debug log viewer.
class DebugViewerConfig {
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

/// Position for floating debug button.
enum FloatingButtonPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
