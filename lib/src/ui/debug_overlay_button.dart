import 'package:flutter/material.dart';

import '../core/logiq.dart';

/// Floating debug button overlay.
class DebugOverlayButton {
  static OverlayEntry? _overlayEntry;

  /// Show the debug button.
  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        right: 16,
        bottom: 100,
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
}
