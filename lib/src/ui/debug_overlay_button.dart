import 'package:flutter/material.dart';

import '../config/debug_viewer_config.dart';
import '../core/logiq.dart';

/// Floating debug button overlay.
class DebugOverlayButton {
  static OverlayEntry? _overlayEntry;

  /// Show the debug button.
  static void show(
    BuildContext context, {
    FloatingButtonPosition position = FloatingButtonPosition.bottomRight,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: _horizontal(position) == _Horizontal.left ? 16 : null,
        right: _horizontal(position) == _Horizontal.right ? 16 : null,
        top: _vertical(position) == _Vertical.top ? 100 : null,
        bottom: _vertical(position) == _Vertical.bottom ? 100 : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Logiq.openViewer(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bug_report,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hide the debug button.
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static _Horizontal _horizontal(FloatingButtonPosition position) {
    switch (position) {
      case FloatingButtonPosition.topLeft:
      case FloatingButtonPosition.bottomLeft:
        return _Horizontal.left;
      case FloatingButtonPosition.topRight:
      case FloatingButtonPosition.bottomRight:
        return _Horizontal.right;
    }
  }

  static _Vertical _vertical(FloatingButtonPosition position) {
    switch (position) {
      case FloatingButtonPosition.topLeft:
      case FloatingButtonPosition.topRight:
        return _Vertical.top;
      case FloatingButtonPosition.bottomLeft:
      case FloatingButtonPosition.bottomRight:
        return _Vertical.bottom;
    }
  }
}

enum _Horizontal { left, right }

enum _Vertical { top, bottom }
