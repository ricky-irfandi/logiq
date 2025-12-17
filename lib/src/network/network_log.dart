/// HTTP request data for network logging.
///
/// Use with [Logiq.logRequest] or [Logiq.network] for structured network logs.
///
/// ```dart
/// Logiq.logRequest(LogiqRequest(
///   method: 'POST',
///   url: 'https://api.example.com/users',
///   headers: {'Authorization': 'Bearer ...'},
///   body: {'name': 'John'},
/// ));
/// ```
class LogiqRequest {
  /// Creates a request log entry.
  const LogiqRequest({
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.timestamp,
  });

  /// HTTP method (GET, POST, PUT, DELETE, etc.)
  final String method;

  /// Request URL
  final String url;

  /// Request headers
  final Map<String, dynamic>? headers;

  /// Request body
  final dynamic body;

  /// When the request was made (defaults to now)
  final DateTime? timestamp;

  /// Converts to a map for logging context.
  Map<String, dynamic> toContext() {
    return {
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    };
  }
}

/// HTTP response data for network logging.
///
/// Use with [Logiq.logResponse] or [Logiq.network] for structured network logs.
///
/// ```dart
/// Logiq.logResponse(LogiqResponse(
///   statusCode: 200,
///   url: 'https://api.example.com/users',
///   body: {'users': [...]},
///   duration: Duration(milliseconds: 234),
/// ));
/// ```
class LogiqResponse {
  /// Creates a response log entry.
  const LogiqResponse({
    required this.statusCode,
    required this.url,
    this.headers,
    this.body,
    this.duration,
    this.requestMethod,
  });

  /// HTTP status code
  final int statusCode;

  /// Response URL
  final String url;

  /// Response headers
  final Map<String, dynamic>? headers;

  /// Response body
  final dynamic body;

  /// Request duration
  final Duration? duration;

  /// Original request method (for context)
  final String? requestMethod;

  /// Whether the response is successful (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response is an error (4xx or 5xx).
  bool get isError => statusCode >= 400;

  /// Converts to a map for logging context.
  Map<String, dynamic> toContext() {
    return {
      'statusCode': statusCode,
      'url': url,
      if (requestMethod != null) 'method': requestMethod,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      'success': isSuccess,
    };
  }
}
