import 'package:flutter/widgets.dart';
import '../core/logiq.dart';
import '../core/log_level.dart';

/// A [NavigatorObserver] that automatically logs navigation events.
///
/// Logs all navigation actions (push, pop, replace, remove) with detailed
/// context including route names, route types, and arguments.
///
/// ## Usage
///
/// Add to your app's navigator observers:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [Logiq.navigationObserver],
///   home: HomePage(),
/// )
/// ```
///
/// ## Configuration
///
/// Create a custom observer with different settings:
///
/// ```dart
/// final observer = LogiqNavigatorObserver(
///   logLevel: LogLevel.debug,
///   category: 'NAVIGATION',
///   logRouteArguments: true,
/// );
///
/// MaterialApp(
///   navigatorObservers: [observer],
/// )
/// ```
///
/// ## Logged Data
///
/// Each navigation event logs:
/// - **action**: The type of navigation (push, pop, replace, remove)
/// - **route**: The current/new route name
/// - **previousRoute**: The previous route name (when applicable)
/// - **routeType**: The class type of the route (e.g., MaterialPageRoute)
/// - **arguments**: Route arguments (if [logRouteArguments] is true)
class LogiqNavigatorObserver extends NavigatorObserver {
  /// Creates a navigation observer that logs navigation events.
  ///
  /// - [enabled]: Whether logging is enabled (default: true)
  /// - [logLevel]: The log level to use (default: LogLevel.info)
  /// - [category]: The log category (default: 'NAV')
  /// - [logRouteArguments]: Whether to include route arguments (default: true)
  LogiqNavigatorObserver({
    this.enabled = true,
    this.logLevel = LogLevel.info,
    this.category = 'NAV',
    this.logRouteArguments = true,
  });

  /// Whether navigation logging is enabled.
  final bool enabled;

  /// The log level used for navigation logs.
  final LogLevel logLevel;

  /// The category used for navigation logs.
  final String category;

  /// Whether to include route arguments in the log context.
  final bool logRouteArguments;

  /// Extracts the route name from a route, with fallbacks.
  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'null';

    // Try to get the route name from settings
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      return name;
    }

    // Fallback to the route type
    return route.runtimeType.toString();
  }

  /// Builds the context map for a navigation event.
  Map<String, dynamic> _buildContext({
    required String action,
    required Route<dynamic>? route,
    Route<dynamic>? previousRoute,
    Route<dynamic>? oldRoute,
    Route<dynamic>? newRoute,
  }) {
    final context = <String, dynamic>{
      'action': action,
    };

    // Add route info based on action type
    if (action == 'replace') {
      context['newRoute'] = _getRouteName(newRoute);
      context['oldRoute'] = _getRouteName(oldRoute);
      if (newRoute != null) {
        context['routeType'] = newRoute.runtimeType.toString();
      }
      // Add arguments from new route
      if (logRouteArguments && newRoute?.settings.arguments != null) {
        context['arguments'] = _safeStringify(newRoute!.settings.arguments);
      }
    } else {
      context['route'] = _getRouteName(route);
      if (previousRoute != null || action == 'pop') {
        context['previousRoute'] = _getRouteName(previousRoute);
      }
      if (route != null) {
        context['routeType'] = route.runtimeType.toString();
      }
      // Add arguments
      if (logRouteArguments && route?.settings.arguments != null) {
        context['arguments'] = _safeStringify(route!.settings.arguments);
      }
    }

    return context;
  }

  /// Safely converts arguments to a loggable format.
  dynamic _safeStringify(dynamic arguments) {
    if (arguments == null) return null;
    if (arguments is Map || arguments is List) return arguments;
    if (arguments is String || arguments is num || arguments is bool) {
      return arguments;
    }
    // For other types, convert to string
    return arguments.toString();
  }

  /// Logs a navigation event using the configured log level.
  void _log(String message, Map<String, dynamic> context) {
    if (!enabled) return;

    switch (logLevel) {
      case LogLevel.verbose:
        Logiq.v(category, message, context);
      case LogLevel.debug:
        Logiq.d(category, message, context);
      case LogLevel.info:
        Logiq.i(category, message, context);
      case LogLevel.warning:
        Logiq.w(category, message, context);
      case LogLevel.error:
        Logiq.e(category, message, context);
      case LogLevel.fatal:
        Logiq.f(category, message, context);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    final routeName = _getRouteName(route);
    final prevName = _getRouteName(previousRoute);

    _log(
      'Navigated to $routeName${previousRoute != null ? ' from $prevName' : ''}',
      _buildContext(
        action: 'push',
        route: route,
        previousRoute: previousRoute,
      ),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    final routeName = _getRouteName(route);
    final prevName = _getRouteName(previousRoute);

    _log(
      'Popped $routeName, returning to $prevName',
      _buildContext(
        action: 'pop',
        route: route,
        previousRoute: previousRoute,
      ),
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    final newName = _getRouteName(newRoute);
    final oldName = _getRouteName(oldRoute);

    _log(
      'Replaced $oldName with $newName',
      _buildContext(
        action: 'replace',
        route: newRoute,
        newRoute: newRoute,
        oldRoute: oldRoute,
      ),
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    final routeName = _getRouteName(route);

    _log(
      'Removed $routeName from navigation stack',
      _buildContext(
        action: 'remove',
        route: route,
        previousRoute: previousRoute,
      ),
    );
  }
}
