import 'package:flutter/material.dart';

/// Configuration for a custom tab in the debug log viewer.
///
/// Allows grouping related log categories into a single tab for easier
/// navigation and filtering.
///
/// ## Example
///
/// ```dart
/// DebugTab(
///   name: 'Network',
///   categories: ['API', 'HTTP', 'Socket'],
///   icon: Icons.wifi,
/// )
/// ```
class DebugTab {
  /// Creates a debug tab configuration.
  ///
  /// - [name]: The display label for the tab (e.g., "Network", "Database")
  /// - [categories]: List of log categories to show in this tab
  /// - [icon]: Optional icon to display alongside the tab name
  const DebugTab({
    required this.name,
    required this.categories,
    this.icon,
  });

  /// Display name of the tab.
  final String name;

  /// List of log categories to include in this tab.
  ///
  /// When this tab is selected, only logs with categories matching
  /// any item in this list will be displayed.
  ///
  /// Category matching is case-sensitive and uses exact string matching.
  final List<String> categories;

  /// Optional icon to display alongside the tab name.
  ///
  /// If null, only the tab name is shown.
  final IconData? icon;

  /// Returns a [Set] of categories for O(1) lookup performance.
  Set<String> get categorySet => categories.toSet();

  /// Creates a copy of this tab with the specified fields replaced.
  DebugTab copyWith({
    String? name,
    List<String>? categories,
    IconData? icon,
  }) {
    return DebugTab(
      name: name ?? this.name,
      categories: categories ?? this.categories,
      icon: icon ?? this.icon,
    );
  }

  @override
  String toString() => 'DebugTab(name: $name, categories: $categories)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebugTab &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _listEquals(categories, other.categories) &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(name, Object.hashAll(categories), icon);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
