/// Function that provides context data to be automatically injected into logs.
///
/// Returns a map of context data, or null to skip adding context for this provider.
///
/// Example:
/// ```dart
/// ContextProvider deviceIdProvider = () => {'deviceId': '12345'};
/// ContextProvider appVersionProvider = () => {'version': '1.0.0'};
/// ContextProvider conditionalProvider = () {
///   if (shouldAddContext) return {'key': 'value'};
///   return null; // Skip this provider
/// };
/// ```
typedef ContextProvider = Map<String, dynamic>? Function();
