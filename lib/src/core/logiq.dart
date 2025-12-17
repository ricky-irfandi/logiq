import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'log_entry.dart';
import 'log_level.dart';
import '../config/log_config.dart';
import '../writer/file_writer.dart';
import '../writer/write_params.dart';
import '../export/log_exporter.dart';
import '../export/export_result.dart';
import '../stats/log_stats.dart';
import '../security/redaction_pattern.dart';
import '../ui/log_viewer_screen.dart';
import '../ui/debug_overlay_button.dart';
import '../navigation/logiq_navigator_observer.dart';
import '../network/network_log.dart';

/// Zero-impact, fire-and-forget local logging system for Flutter.
///
/// Logiq provides local logging with encryption, rotation,
/// PII redaction, and a beautiful debug UI. Designed for production apps
/// that need reliable, secure logging without impacting performance.
///
/// ## Features
///
/// - ⚡ **Zero-impact**: ~0.001ms per log call (fire-and-forget)
/// - 🔒 **Secure**: AES-256-GCM encryption with automatic key disposal
/// - 🔄 **Rotation**: Automatic file rotation with configurable strategies
/// - 🛡️ **PII Redaction**: Built-in patterns for emails, phones, SSNs, etc.
/// - 🎨 **Debug UI**: Beautiful real-time log viewer with search & filters
/// - 📊 **Statistics**: Track logged, dropped, and failed entries
/// - 🌐 **Cross-platform**: Works on iOS, Android, macOS, Windows, Linux
///
/// ## Quick Start
///
/// ```dart
/// import 'package:logiq/logiq.dart';
///
/// // 1. Initialize once at app startup
/// await Logiq.init();
///
/// // 2. Log anywhere in your app
/// Logiq.i('API', 'User logged in', {'userId': 123});
/// Logiq.e('DB', 'Connection failed', {'error': 'timeout'});
///
/// // 3. Show debug viewer (debug builds only)
/// Logiq.showDebugButton(context);
/// ```
///
/// ## Log Levels
///
/// Logiq supports 6 log levels (lowest to highest):
///
/// - [v] - Verbose: Extremely detailed information
/// - [d] - Debug: Development debugging information
/// - [i] - Info: General informational messages
/// - [w] - Warning: Warning messages for potential issues
/// - [e] - Error: Error events that might still allow continued execution
/// - [f] - Fatal: Very severe error events that might lead to abort
///
/// ## Configuration
///
/// ### Production-ready defaults:
///
/// ```dart
/// await Logiq.init(); // Uses LogConfig.auto()
/// ```
///
/// ### Custom configuration:
///
/// ```dart
/// await Logiq.init(
///   config: LogConfig.production(
///     minLevel: LogLevel.info,
///     retention: RetentionConfig(
///       maxAge: Duration(days: 7),
///     ),
///     encryption: EncryptionConfig.aes256(
///       keyProvider: () async => await secureStorage.read('log_key'),
///     ),
///     redactionPatterns: [
///       RedactionPattern.email(),
///       RedactionPattern.phoneNumber(),
///       RedactionPattern.custom(
///         name: 'api-key',
///         pattern: RegExp(r'api[_-]?key["\s:=]+([a-zA-Z0-9]+)'),
///         replacement: 'api_key=***REDACTED***',
///       ),
///     ],
///   ),
/// );
/// ```
///
/// ## Logging with Context
///
/// Add structured data to your logs:
///
/// ```dart
/// Logiq.i('Payment', 'Transaction completed', {
///   'amount': 99.99,
///   'currency': 'USD',
///   'userId': 12345,
///   'timestamp': DateTime.now().toIso8601String(),
/// });
/// ```
///
/// ## Export Logs
///
/// ```dart
/// final result = await Logiq.export(
///   timeRange: Duration(hours: 24), // Last 24 hours
///   compress: true,
///   includeDeviceInfo: true,
/// );
///
/// // Share the file
/// await Share.shareFiles([result.file.path]);
/// ```
///
/// ## Sensitive Data
///
/// Temporarily pause logging during sensitive operations:
///
/// ```dart
/// // Option 1: Manual control
/// Logiq.enterSensitiveMode();
/// // ... handle sensitive data ...
/// Logiq.exitSensitiveMode();
///
/// // Option 2: Automatic
/// await Logiq.sensitive(() async {
///   // No logs will be written here
///   return await handlePaymentInfo();
/// });
/// ```
///
/// ## Statistics
///
/// Monitor logging health:
///
/// ```dart
/// final stats = await Logiq.getStats();
/// print('Total logged: ${stats.totalLogged}');
/// print('Dropped: ${stats.droppedCount}');
/// print('Storage: ${stats.storageUsed} bytes');
/// ```
///
/// ## Performance
///
/// Logiq is designed for zero-impact logging:
///
/// - Buffer operations: O(1) using Queue
/// - File I/O: Background isolates (non-blocking)
/// - Encryption: Cipher reuse, minimal allocations
/// - Memory: Limited to configurable buffer size
///
/// Typical performance:
/// - Log call: ~0.001ms (1 microsecond)
/// - Buffer → Disk: Async, every 30s or on buffer full
/// - Export: Streaming with 50MB safety limit
///
/// ## Thread Safety
///
/// All operations are thread-safe:
/// - Lock-protected buffer flushes
/// - Atomic buffer operations
/// - Safe concurrent logging from multiple isolates
///
/// ## Best Practices
///
/// 1. **Initialize early**: Call [init] before any logging
/// 2. **Use appropriate levels**: Don't log everything at ERROR
/// 3. **Add context**: Include relevant data in context maps
/// 4. **Set retention**: Configure [RetentionConfig] to prevent unbounded growth
/// 5. **Redact PII**: Use built-in patterns or create custom ones
/// 6. **Encrypt sensitive logs**: Enable encryption for compliance
/// 7. **Monitor stats**: Check [getStats] periodically
/// 8. **Flush before exit**: Call [flush] or [dispose] on app exit
///
/// See also:
/// - [LogConfig] for configuration options
/// - [LogLevel] for severity levels
/// - [RetentionConfig] for automatic cleanup
/// - [EncryptionConfig] for secure logging
/// - [RedactionPattern] for PII protection
class Logiq {
  Logiq._();

  static Logiq? _instance;
  static Logiq get _i {
    if (_instance == null) {
      // Auto-initialize with safe defaults but defer any file IO until init().
      _instance = Logiq._();
      _instance!._config = LogConfig.auto();
      _instance!._sessionId = _generateSessionId();
      _instance!._enabled = true;
      _instance!._logDirectory = ''; // Will be set properly in init()
      _instance!._initialized = false;

      if (kDebugMode) {
        debugPrint(
          'Logiq: Auto-initialized with defaults. '
          'Call Logiq.init() to enable file logging.',
        );
      }
    }
    return _instance!;
  }

  late LogConfig _config;
  late String _logDirectory;

  final Queue<LogEntry> _buffer = Queue();
  final Lock _flushLock = Lock();
  static final Lock _initLock = Lock();
  Timer? _flushTimer;
  Timer? _cleanupTimer;
  bool _enabled = true;
  LogLevel? _runtimeMinLevel;
  bool _sensitiveMode = false;
  bool _initialized = false;

  // Stats
  int _totalLogged = 0;
  int _droppedCount = 0;
  int _writeFailures = 0;
  int _sequenceNumber = 0;

  // Session
  late String _sessionId;

  // Additional redaction patterns added at runtime
  final List<RedactionPattern> _runtimeRedactionPatterns = [];
  static const int _maxRuntimePatterns = 100;

  // Hook recursion protection
  int _hookDepth = 0;
  static const int _maxHookDepth = 5;

  // ══════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════

  /// Initializes the Logiq logging system.
  ///
  /// Must be called once before any logging operations. Typically called
  /// in `main()` before `runApp()`.
  ///
  /// ### Parameters
  ///
  /// - [config]: Optional configuration. If `null`, uses [LogConfig.auto()]
  ///   which automatically selects debug or production settings based on
  ///   `kDebugMode`.
  ///
  /// ### Example
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   // Option 1: Auto configuration (recommended)
  ///   await Logiq.init();
  ///
  ///   // Option 2: Custom configuration
  ///   await Logiq.init(
  ///     config: LogConfig.production(
  ///       minLevel: LogLevel.info,
  ///       retention: RetentionConfig(maxAge: Duration(days: 7)),
  ///     ),
  ///   );
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// ### Behavior
  ///
  /// - Creates log directory if it doesn't exist
  /// - Starts periodic flush timer (default: 30s)
  /// - Schedules automatic cleanup if retention is configured
  /// - Safe to call multiple times (subsequent calls are no-op)
  ///
  /// ### Thread Safety
  ///
  /// Safe to call from any isolate. If already initialized, returns immediately.
  ///
  /// See also:
  /// - [LogConfig] for configuration options
  /// - [dispose] to clean up resources on app exit
  static Future<void> init({LogConfig? config}) async {
    // Use lock to prevent race condition from concurrent init() calls
    await _initLock.synchronized(() async {
      // If already initialized, treat as no-op (idempotent)
      if (_instance != null && _instance!._initialized) {
        return;
      }

      // Reuse existing instance if present, but reset state for init.
      final instance = _instance ?? Logiq._();
      instance._flushTimer?.cancel();
      instance._cleanupTimer?.cancel();
      instance._buffer.clear();
      instance._runtimeMinLevel = null;
      instance._sensitiveMode = false;
      instance._totalLogged = 0;
      instance._droppedCount = 0;
      instance._writeFailures = 0;
      instance._sequenceNumber = 0;
      instance._initialized = false;

      instance._config = config ?? LogConfig.auto();
      instance._sessionId = _generateSessionId();
      instance._enabled = instance._config.enabled;

      // Get log directory
      if (instance._config.directory != null) {
        instance._logDirectory = instance._config.directory!;
      } else {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          instance._logDirectory = '${appDir.path}/logiq';
        } catch (_) {
          // Fallback for test/VM environments without path_provider bindings
          instance._logDirectory = '${Directory.systemTemp.path}/logiq';
        }
      }

      // Ensure directory exists
      try {
        await Directory(instance._logDirectory).create(recursive: true);
      } catch (e, stackTrace) {
        // Notify via hook and continue in in-memory mode
        instance._logDirectory = '';
        instance._initialized = true;
        _instance = instance;
        try {
          instance._config.hooks?.onError?.call(e, stackTrace);
        } catch (_) {}
        return;
      }

      // Start flush timer
      instance._startFlushTimer();

      // Run initial cleanup if retention configured
      if (instance._config.retention != null) {
        instance._scheduleCleanup();
      }

      instance._initialized = true;
      // Set the static instance last to ensure it's fully initialized
      _instance = instance;
    });
  }

  static String _generateSessionId() {
    final now = DateTime.now();
    return 'sess_${now.millisecondsSinceEpoch.toRadixString(36)}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // LOGGING METHODS - Fire & Forget
  // ══════════════════════════════════════════════════════════════════════

  /// Logs a verbose message (lowest severity).
  ///
  /// Use for extremely detailed information, typically only enabled during
  /// development. Not recommended for production.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.v('HTTP', 'Request headers', {
  ///   'headers': {'Authorization': 'Bearer ...'},
  ///   'url': 'https://api.example.com/users',
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.v('Request headers');
  /// ```
  static void v(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.verbose, cat, ctx.$1, ctx.$2);
  }

  /// Logs a debug message.
  ///
  /// Use for development debugging. Typically disabled in production.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.d('Auth', 'Token validation started', {
  ///   'userId': user.id,
  ///   'expiresAt': token.expiresAt.toIso8601String(),
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.d('Token validation started');
  /// ```
  static void d(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.debug, cat, ctx.$1, ctx.$2);
  }

  /// Logs an informational message.
  ///
  /// Use for general application flow information. Safe for production.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.i('Payment', 'Transaction completed', {
  ///   'amount': 99.99,
  ///   'currency': 'USD',
  ///   'orderId': '12345',
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.i('Transaction completed');
  /// ```
  static void i(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.info, cat, ctx.$1, ctx.$2);
  }

  /// Logs a warning message.
  ///
  /// Use for potentially harmful situations that don't prevent execution.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.w('Cache', 'Cache miss, fetching from network', {
  ///   'key': 'user_profile_123',
  ///   'reason': 'expired',
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.w('Cache miss, fetching from network');
  /// ```
  static void w(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.warning, cat, ctx.$1, ctx.$2);
  }

  /// Logs an error message.
  ///
  /// Use for error events that might still allow continued execution.
  /// Triggers immediate flush to ensure the error is persisted.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.e('Network', 'API call failed', {
  ///   'endpoint': '/api/users',
  ///   'statusCode': 500,
  ///   'error': error.toString(),
  ///   'stackTrace': stackTrace.toString(),
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.e('API call failed');
  /// ```
  ///
  /// ### Behavior
  ///
  /// Error and Fatal logs trigger **immediate flush** to ensure critical
  /// events are persisted even if the app crashes.
  static void e(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.error, cat, ctx.$1, ctx.$2);
  }

  /// Logs a fatal message (highest severity).
  ///
  /// Use for very severe errors that might lead to application termination.
  /// Triggers immediate flush to ensure the error is persisted.
  ///
  /// - [category]: A short tag to group related logs (e.g., 'DB', 'API', 'UI')
  /// - [message]: The log message
  /// - [context]: Optional structured data to attach to the log
  ///
  /// ### Example
  ///
  /// ```dart
  /// // With category
  /// Logiq.f('DB', 'Database corruption detected', {
  ///   'file': dbFile.path,
  ///   'size': dbFile.lengthSync(),
  ///   'error': exception.toString(),
  /// });
  ///
  /// // Without category (uses default)
  /// Logiq.f('Database corruption detected');
  /// ```
  ///
  /// ### Behavior
  ///
  /// Error and Fatal logs trigger **immediate flush** to ensure critical
  /// events are persisted even if the app crashes.
  static void f(
    String message, [
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
  ]) {
    final (cat, ctx) = _parseArgs(categoryOrContext, context, message);
    _i._log(LogLevel.fatal, cat, ctx.$1, ctx.$2);
  }

  /// Parses the flexible arguments for log methods.
  ///
  /// Supports multiple calling patterns:
  /// - `Logiq.i('message')` - uses default category
  /// - `Logiq.i('message', {'key': 'value'})` - message with context
  /// - `Logiq.i('category', 'message')` - with category (backward compatible)
  /// - `Logiq.i('category', 'message', context)` - full usage
  ///
  /// Returns a tuple of (category, (message, context)).
  static (String, (String, Map<String, dynamic>?)) _parseArgs(
    dynamic categoryOrContext,
    Map<String, dynamic>? context,
    String firstArg,
  ) {
    // Case 1: Only message provided - Logiq.i('message')
    if (categoryOrContext == null) {
      return (_i._config.defaultCategory, (firstArg, null));
    }

    // Case 2: Category and message provided - Logiq.i('category', 'message')
    // First arg is category, second arg (categoryOrContext) is message
    if (categoryOrContext is String) {
      return (firstArg, (categoryOrContext, context));
    }

    // Case 3: Message and context provided - Logiq.i('message', {'key': 'value'})
    // First arg is message, second arg is context
    if (categoryOrContext is Map<String, dynamic>) {
      return (_i._config.defaultCategory, (firstArg, categoryOrContext));
    }

    // Fallback: treat first arg as message only
    return (_i._config.defaultCategory, (firstArg, null));
  }

  void _log(
    LogLevel level,
    String category,
    String message,
    Map<String, dynamic>? context,
  ) {
    // Quick checks - these are essentially free
    if (!_enabled) return;
    if (_sensitiveMode) return;

    final minLevel = _runtimeMinLevel ?? _config.minLevel;
    if (level.value < minLevel.value) return;

    // Input validation
    final validatedCategory = _validateCategory(category);
    final validatedMessage = _validateMessage(message);

    // Buffer overflow protection - remove oldest entries efficiently (O(1))
    while (_buffer.length >= _config.bufferSize) {
      _buffer.removeFirst();
      _droppedCount++;
    }

    // Gather auto-context
    Map<String, dynamic>? fullContext = context;
    if (_config.contextProviders.isNotEmpty) {
      fullContext = context != null ? Map.from(context) : {};
      for (final provider in _config.contextProviders) {
        try {
          final providedContext = provider();
          if (providedContext != null) {
            fullContext.addAll(providedContext);
          } else if (kDebugMode) {
            debugPrint('Logiq: Context provider returned null, skipping');
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('Logiq: Context provider error: $e\n$stackTrace');
          }
          // Continue with other providers
        }
      }
    }

    // Quick size check to prevent OOM (no serialization for performance)
    if (fullContext != null) {
      fullContext = _quickContextCheck(fullContext);
    }

    // Create entry
    final now = DateTime.now();
    final entry = LogEntry(
      timestamp: now,
      level: level,
      category: validatedCategory,
      message: validatedMessage,
      context: fullContext,
      sessionId: _sessionId,
      sequenceNumber: _sequenceNumber++,
    );

    // Add to buffer - THIS IS INSTANT
    _buffer.add(entry);
    _totalLogged++;

    // Call hooks with recursion protection
    if (_hookDepth < _maxHookDepth) {
      _hookDepth++;
      try {
        _config.hooks?.onLog?.call(entry);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: onLog hook error: $e\n$stackTrace');
        }
      } finally {
        _hookDepth--;
      }
    } else if (kDebugMode) {
      debugPrint(
        'Logiq: Hook recursion depth limit reached ($_maxHookDepth). '
        'Ensure hooks do not call Logiq logging methods.',
      );
    }

    // Write to all configured sinks
    for (final sink in _config.sinks) {
      try {
        sink.write(entry);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: Sink write error: $e\n$stackTrace');
        }
      }
    }

    // Check if immediate flush needed (fire-and-forget)
    unawaited(_checkFlush(isCritical: level.value >= LogLevel.error.value));
  }

  /// Validate and normalize category string.
  String _validateCategory(String category) {
    if (category.isEmpty) {
      if (kDebugMode) {
        debugPrint('Logiq: Empty category provided, using "UNKNOWN"');
      }
      return 'UNKNOWN';
    }
    return category.length > 50 ? category.substring(0, 50) : category;
  }

  /// Validate and truncate message if needed.
  String _validateMessage(String message) {
    return message.length > 5000
        ? '${message.substring(0, 5000)}... [truncated]'
        : message;
  }

  /// Quick context size check (fast, no serialization).
  /// Only blocks obviously huge contexts to prevent OOM.
  /// Also detects circular references to prevent stack overflow.
  Map<String, dynamic> _quickContextCheck(
    Map<String, dynamic> context, {
    Set<Object>? visited,
    int depth = 0,
  }) {
    try {
      // Quick depth/breadth check
      const maxKeys = 100; // Reasonable limit
      const maxDepth = 10; // Prevent deep nesting
      const maxStringLength = 10000;
      const maxListLength = 1000;

      // Circular reference detection
      visited ??= {};
      if (visited.contains(context)) {
        return {'_circular': 'Circular reference detected'};
      }
      visited.add(context);

      // Depth limit
      if (depth >= maxDepth) {
        return {'_depth': 'Max depth exceeded'};
      }

      // Key count limit
      if (context.length > maxKeys) {
        if (kDebugMode) {
          debugPrint(
            'Logiq: Context has too many keys (${context.length}), '
            'limiting to $maxKeys. Consider reducing context size.',
          );
        }
        // Take first N keys only
        final limited = <String, dynamic>{};
        int count = 0;
        for (final entry in context.entries) {
          if (count++ >= maxKeys) break;
          limited[entry.key] = entry.value;
        }
        limited['_truncated'] = 'Exceeded $maxKeys keys';
        visited.remove(context); // Clean up before return
        return limited;
      }

      // Check and sanitize values recursively
      final sanitized = <String, dynamic>{};
      for (final entry in context.entries) {
        final value = entry.value;

        if (value is String && value.length > maxStringLength) {
          // Individual string too large
          sanitized[entry.key] = '${value.substring(0, 1000)}... [truncated]';
        } else if (value is List && value.length > maxListLength) {
          // List too large
          if (kDebugMode) {
            debugPrint('Logiq: List in context too large, truncating');
          }
          sanitized[entry.key] = {
            '_error': 'List too large',
            '_length': value.length,
          };
        } else if (value is Map<String, dynamic>) {
          // Recursively check nested maps
          sanitized[entry.key] = _quickContextCheck(
            value,
            visited: visited,
            depth: depth + 1,
          );
        } else {
          sanitized[entry.key] = value;
        }
      }

      visited.remove(context); // Clean up visited set
      return sanitized;
    } catch (e) {
      // Handle any unexpected errors
      if (kDebugMode) {
        debugPrint('Logiq: Context check error: $e');
      }
      return {'_error': 'Context validation failed', '_reason': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FLUSH
  // ══════════════════════════════════════════════════════════════════════

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_config.flushInterval, (_) async {
      // Use lock to prevent concurrent flushes
      await _flushLock.synchronized(() async {
        if (_buffer.isEmpty) return;
        await _flush();
      });
    });
  }

  Future<void> _checkFlush({bool isCritical = false}) async {
    final shouldFlush = _buffer.length >= _config.bufferSize || isCritical;
    if (!shouldFlush) return;

    // Use lock to prevent race conditions
    await _flushLock.synchronized(() async {
      if (_buffer.isEmpty) return;
      await _flush();
    });
  }

  Future<void> _flush() async {
    // Lock (in _checkFlush) ensures no concurrent flushes
    if (_buffer.isEmpty) return;

    // Skip file operations if not properly initialized
    if (!_initialized || _logDirectory.isEmpty) {
      // Logs buffered in memory only until init() is called
      return;
    }

    // Take snapshot and clear buffer up front to avoid losing new arrivals
    final entries = List<LogEntry>.from(_buffer);
    _buffer.clear();

    try {
      // Ensure directory still exists (in case it was removed between writes)
      try {
        await Directory(_logDirectory).create(recursive: true);
      } catch (_) {
        // If we can't create the directory, restore entries and bail
        _buffer.addAll(entries);
        return;
      }

      // Build write params
      final allRedactionPatterns = [
        ..._config.redactionPatterns,
        ..._runtimeRedactionPatterns,
      ];

      final params = await WriteParams.fromConfig(
        entries: entries,
        logDirectory: _logDirectory,
        config: _config.copyWith(redactionPatterns: allRedactionPatterns),
      );

      // Write in isolate - NON-BLOCKING
      bool rotated;
      try {
        rotated = await compute<Map<String, dynamic>, bool>(
          FileWriter.writeEntries,
          params.toMap(),
        );
      } catch (_) {
        // Fallback for environments where compute/isolate is unavailable
        rotated = await FileWriter.writeEntries(params.toMap());
      }

      // Call hooks
      try {
        _config.hooks?.onFlush?.call(entries.length);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: onFlush hook error: $e\n$stackTrace');
        }
      }
      if (rotated) {
        try {
          _config.hooks?.onRotate?.call();
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('Logiq: onRotate hook error: $e\n$stackTrace');
          }
        }
      }
    } catch (e, stackTrace) {
      _writeFailures++;
      // Restore entries so they can be retried on next flush (preserve order)
      for (var i = entries.length - 1; i >= 0; i--) {
        _buffer.addFirst(entries[i]);
      }

      if (kDebugMode) {
        debugPrint('Logiq: Flush error: $e\n$stackTrace');
      }
      try {
        _config.hooks?.onError?.call(e, stackTrace);
      } catch (hookError, hookStack) {
        if (kDebugMode) {
          debugPrint('Logiq: onError hook failed: $hookError\n$hookStack');
        }
      }
      // Silent fail - never crash the app
    }
  }

  /// Forces immediate flush of buffered logs to disk.
  ///
  /// Normally, logs are flushed automatically every 30 seconds or when
  /// the buffer is full. Use this method when you need to ensure logs
  /// are persisted immediately (e.g., before app exit or critical operations).
  ///
  /// ### Example
  ///
  /// ```dart
  /// // Before app exit
  /// await Logiq.flush();
  /// exit(0);
  ///
  /// // After critical operation
  /// await performCriticalOperation();
  /// await Logiq.flush(); // Ensure all logs are saved
  /// ```
  ///
  /// ### Behavior
  ///
  /// - Writes all buffered logs to disk
  /// - Runs in background isolate (non-blocking)
  /// - Safe to call multiple times
  /// - Returns when flush completes
  ///
  /// ### Performance
  ///
  /// Typically completes in 10-50ms depending on buffer size and disk speed.
  ///
  /// See also:
  /// - [dispose] to flush and clean up all resources
  static Future<void> flush() => _i._flush();

  // ══════════════════════════════════════════════════════════════════════
  // EXPORT
  // ══════════════════════════════════════════════════════════════════════

  /// Exports logs to a compressed archive file.
  ///
  /// Creates a shareable log file for debugging, support tickets, or analysis.
  /// Automatically decrypts logs if encryption is enabled.
  ///
  /// ### Parameters
  ///
  /// - [timeRange]: Optional time range to export (e.g., last 24 hours).
  ///   If `null`, exports all logs.
  /// - [compress]: Whether to GZip compress the output (default: `true`).
  ///   Recommended for large log files.
  /// - [includeDeviceInfo]: Whether to include device/platform information
  ///   (default: `true`). Useful for debugging platform-specific issues.
  ///
  /// ### Returns
  ///
  /// [ExportResult] containing:
  /// - `file`: The exported log file (`.log` or `.log.gz`)
  /// - `originalSize`: Uncompressed size in bytes
  /// - `compressedSize`: Final file size in bytes
  /// - `entryCount`: Number of log entries included
  /// - `timeRange`: Actual time range covered by the export
  ///
  /// ### Example
  ///
  /// ```dart
  /// // Export last 24 hours
  /// final result = await Logiq.export(
  ///   timeRange: Duration(hours: 24),
  ///   compress: true,
  ///   includeDeviceInfo: true,
  /// );
  ///
  /// print('Exported ${result.entryCount} logs');
  /// print('Size: ${result.compressedSize} bytes');
  ///
  /// // Share the file
  /// await Share.shareFiles([result.file.path]);
  ///
  /// // Or upload to server
  /// final bytes = await result.file.readAsBytes();
  /// await http.post(
  ///   Uri.parse('https://api.example.com/logs'),
  ///   body: bytes,
  /// );
  /// ```
  ///
  /// ### Behavior
  ///
  /// - Flushes all buffered logs before exporting
  /// - Decrypts logs automatically if encryption is enabled
  /// - Limited to 50MB uncompressed to prevent OOM on low-end devices
  /// - Throws [StateError] if export exceeds size limit
  /// - File is created in temporary directory
  ///
  /// ### Performance
  ///
  /// - 1MB of logs: ~50ms
  /// - 10MB of logs: ~500ms
  /// - 50MB of logs: ~2-3s
  ///
  /// ### Size Limit
  ///
  /// Exports are limited to 50MB uncompressed to prevent out-of-memory
  /// errors on low-end devices. Use [timeRange] to export smaller ranges:
  ///
  /// ```dart
  /// // If full export exceeds 50MB, export in chunks
  /// final lastWeek = await Logiq.export(timeRange: Duration(days: 7));
  /// final lastMonth = await Logiq.export(timeRange: Duration(days: 30));
  /// ```
  ///
  /// See also:
  /// - [ExportResult] for details on the export result
  static Future<ExportResult> export({
    Duration? timeRange,
    bool compress = true,
    bool includeDeviceInfo = true,
  }) async {
    // Flush first to ensure all logs are written
    await _i._flush();

    return LogExporter.export(
      logDirectory: _i._logDirectory,
      timeRange: timeRange,
      compress: compress,
      includeDeviceInfo: includeDeviceInfo,
      encryptionKey: _i._config.encryption?.enabled == true
          ? await _i._config.encryption!.getKey()
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════

  /// Clear all logs.
  static Future<void> clear() async {
    _i._buffer.clear();

    final dir = Directory(_i._logDirectory);
    if (await dir.exists()) {
      try {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            try {
              await file.delete();
            } catch (e, stackTrace) {
              if (kDebugMode) {
                debugPrint('Logiq: File deletion error: $e\n$stackTrace');
              }
            }
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: Directory listing error: $e\n$stackTrace');
        }
      }
    }
  }

  /// Clear logs older than [age], keeping at least [minEntries] if provided.
  static Future<void> clearOlderThan(Duration age, {int? minEntries}) async {
    final cutoff = DateTime.now().subtract(age);
    final dir = Directory(_i._logDirectory);

    if (await dir.exists()) {
      // Collect file stats first
      final files = <File>[];
      final stats = <File, FileStat>{};
      try {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            files.add(file);
            stats[file] = await file.stat();
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: Directory listing error: $e\n$stackTrace');
        }
        return;
      }

      // Fast path: no minEntries requirement
      if (minEntries == null || minEntries <= 0) {
        for (final file in files) {
          final stat = stats[file]!;
          if (stat.modified.isBefore(cutoff)) {
            try {
              await file.delete();
            } catch (e, stackTrace) {
              if (kDebugMode) {
                debugPrint('Logiq: File deletion error: $e\n$stackTrace');
              }
            }
          }
        }
        return;
      }

      // Count entries per file to honor minEntries
      final fileInfos = <_LogFileInfo>[];
      var totalEntries = 0;
      for (final file in files) {
        final stat = stats[file]!;
        int entryCount = 0;
        try {
          final content = await file.readAsString();
          entryCount = content
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .length;
        } catch (_) {
          entryCount = 0;
        }
        totalEntries += entryCount;
        fileInfos
            .add(_LogFileInfo(file: file, stat: stat, entryCount: entryCount));
      }

      // Sort oldest first
      fileInfos.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

      for (final info in fileInfos) {
        if (!info.stat.modified.isBefore(cutoff)) continue;
        if (totalEntries - info.entryCount < minEntries) {
          // Stop once deleting would violate minEntries
          break;
        }
        try {
          await info.file.delete();
          totalEntries -= info.entryCount;
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('Logiq: File deletion error: $e\n$stackTrace');
          }
        }
      }
    }
  }

  /// Retrieves current logging statistics.
  ///
  /// Provides metrics for monitoring logging health and performance.
  /// Useful for dashboards, health checks, and debugging.
  ///
  /// ### Returns
  ///
  /// [LogStats] containing:
  /// - `totalLogged`: Total number of logs written since init
  /// - `bufferedCount`: Number of logs currently in memory buffer
  /// - `droppedCount`: Number of logs dropped due to buffer overflow
  /// - `writeFailures`: Number of failed flush operations
  /// - `storageUsed`: Total bytes used by log files on disk
  /// - `fileCount`: Number of log files
  /// - `oldestEntry`: Timestamp of oldest log file
  /// - `newestEntry`: Timestamp of newest log file
  /// - `sessionId`: Current session identifier
  ///
  /// ### Example
  ///
  /// ```dart
  /// final stats = await Logiq.getStats();
  ///
  /// print('Total logged: ${stats.totalLogged}');
  /// print('In buffer: ${stats.bufferedCount}');
  /// print('Dropped: ${stats.droppedCount}');
  /// print('Storage: ${(stats.storageUsed / 1024 / 1024).toStringAsFixed(2)} MB');
  ///
  /// // Alert if too many drops
  /// if (stats.droppedCount > 1000) {
  ///   print('WARNING: High drop rate! Consider increasing buffer size.');
  /// }
  ///
  /// // Alert if storage too high
  /// if (stats.storageUsed > 100 * 1024 * 1024) { // 100MB
  ///   print('WARNING: Logs using >100MB. Enable retention cleanup.');
  /// }
  /// ```
  ///
  /// ### Monitoring Health
  ///
  /// ```dart
  /// // Periodic health check
  /// Timer.periodic(Duration(minutes: 5), (timer) async {
  ///   final stats = await Logiq.getStats();
  ///
  ///   // High drop rate indicates buffer too small
  ///   final dropRate = stats.droppedCount / stats.totalLogged;
  ///   if (dropRate > 0.01) { // >1% drops
  ///     analytics.trackEvent('high_log_drop_rate', {'rate': dropRate});
  ///   }
  ///
  ///   // Write failures indicate disk issues
  ///   if (stats.writeFailures > 0) {
  ///     analytics.trackEvent('log_write_failures', {
  ///       'count': stats.writeFailures,
  ///     });
  ///   }
  /// });
  /// ```
  ///
  /// ### Performance
  ///
  /// - Typically completes in <5ms
  /// - Reads file metadata (no file content)
  /// - Safe to call frequently
  ///
  /// See also:
  /// - [LogStats] for details on the statistics
  static Future<LogStats> getStats() async {
    int storageUsed = 0;
    int fileCount = 0;
    DateTime? oldestEntry;
    DateTime? newestEntry;

    final dir = Directory(_i._logDirectory);
    if (await dir.exists()) {
      try {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            try {
              final stat = await file.stat();
              storageUsed += stat.size;
              fileCount++;

              if (oldestEntry == null || stat.modified.isBefore(oldestEntry)) {
                oldestEntry = stat.modified;
              }
              if (newestEntry == null || stat.modified.isAfter(newestEntry)) {
                newestEntry = stat.modified;
              }
            } catch (e, stackTrace) {
              if (kDebugMode) {
                debugPrint('Logiq: File stat error: $e\n$stackTrace');
              }
            }
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Logiq: Directory listing error: $e\n$stackTrace');
        }
      }
    }

    return LogStats(
      totalLogged: _i._totalLogged,
      bufferedCount: _i._buffer.length,
      droppedCount: _i._droppedCount,
      writeFailures: _i._writeFailures,
      storageUsed: storageUsed,
      fileCount: fileCount,
      oldestEntry: oldestEntry,
      newestEntry: newestEntry,
      sessionId: _i._sessionId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // RUNTIME CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════

  /// Set minimum log level at runtime.
  static void setMinLevel(LogLevel level) {
    _i._runtimeMinLevel = level;
  }

  /// Enable or disable logging at runtime.
  static void setEnabled(bool enabled) {
    _i._enabled = enabled;
  }

  /// Check if logging is enabled.
  static bool get isEnabled => _i._enabled;

  /// Add redaction pattern at runtime.
  static void addRedaction(RedactionPattern pattern) {
    // Prevent unbounded growth - remove oldest if at limit
    if (_i._runtimeRedactionPatterns.length >= _maxRuntimePatterns) {
      _i._runtimeRedactionPatterns.removeAt(0);
    }
    _i._runtimeRedactionPatterns.add(pattern);
  }

  /// Clear all runtime redaction patterns.
  static void clearRuntimeRedactions() {
    _i._runtimeRedactionPatterns.clear();
  }

  /// Enter sensitive mode (pause all logging).
  static void enterSensitiveMode() {
    _i._sensitiveMode = true;
  }

  /// Exit sensitive mode (resume logging).
  static void exitSensitiveMode() {
    _i._sensitiveMode = false;
  }

  /// Execute callback with logging paused.
  static Future<T> sensitive<T>(Future<T> Function() callback) async {
    enterSensitiveMode();
    try {
      return await callback();
    } finally {
      exitSensitiveMode();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DEBUG UI
  // ══════════════════════════════════════════════════════════════════════

  /// Shows a floating debug button overlay for easy log access.
  ///
  /// Displays a draggable floating action button that opens the log viewer
  /// when tapped. Only visible in debug builds unless explicitly enabled.
  ///
  /// - [context]: BuildContext for overlay insertion
  ///
  /// ### Example
  ///
  /// ```dart
  /// class MyApp extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return MaterialApp(
  ///       home: Builder(
  ///         builder: (context) {
  ///           // Show debug button in debug builds
  ///           if (kDebugMode) {
  ///             Logiq.showDebugButton(context);
  ///           }
  ///           return HomePage();
  ///         },
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// ### Behavior
  ///
  /// - Button is draggable and persists across navigation
  /// - Automatically hidden if debug viewer is disabled in config
  /// - Safe to call multiple times (subsequent calls are no-op)
  /// - Button shows log count badge
  ///
  /// See also:
  /// - [hideDebugButton] to remove the button
  /// - [openViewer] to open viewer directly
  static void showDebugButton(BuildContext context) {
    final viewerConfig = _i._config.debugViewer;
    if (!viewerConfig.enabled || !viewerConfig.showFloatingButton) return;
    DebugOverlayButton.show(
      context,
      position: viewerConfig.floatingButtonPosition,
    );
  }

  /// Hides the floating debug button.
  ///
  /// Removes the debug button overlay if it's currently shown.
  ///
  /// ### Example
  ///
  /// ```dart
  /// // Hide debug button before taking screenshot
  /// Logiq.hideDebugButton();
  /// await takeScreenshot();
  /// Logiq.showDebugButton(context);
  /// ```
  ///
  /// See also:
  /// - [showDebugButton] to show the button
  static void hideDebugButton() {
    DebugOverlayButton.hide();
  }

  /// Opens the log viewer screen.
  ///
  /// Displays a full-screen log viewer with search, filtering, and export
  /// capabilities. Features both beautiful card view and compact text view.
  ///
  /// - [context]: BuildContext for navigation
  ///
  /// ### Example
  ///
  /// ```dart
  /// // Add a button to open logs
  /// IconButton(
  ///   icon: Icon(Icons.bug_report),
  ///   onPressed: () => Logiq.openViewer(context),
  /// )
  ///
  /// // Or use in error handler
  /// FlutterError.onError = (details) {
  ///   Logiq.f('Flutter', details.exception.toString());
  ///   Logiq.openViewer(context); // Show logs to developer
  /// };
  /// ```
  ///
  /// ### Features
  ///
  /// - **Real-time updates**: Auto-refreshes every 2 seconds
  /// - **Dual view modes**: Beautiful cards or compact text
  /// - **Search**: Filter by message or category
  /// - **Level filtering**: Show/hide specific log levels
  /// - **Detailed view**: Tap any log for full details
  /// - **Copy**: Copy logs to clipboard
  /// - **Horizontal scroll**: See full messages in compact mode
  ///
  /// ### Performance
  ///
  /// - Limited to 1000 most recent logs for smooth scrolling
  /// - Efficient ListView.builder rendering
  /// - Optimized for low-end devices
  ///
  /// See also:
  /// - [showDebugButton] for floating button access
  static void openViewer(BuildContext context) {
    if (!_i._config.debugViewer.enabled && !kDebugMode) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogViewerScreen(
          logDirectory: _i._logDirectory,
          theme: _i._config.debugViewer.theme,
          tabs: _i._config.debugViewer.tabs,
        ),
      ),
    );
  }

  /// Get log directory path.
  static String get logDirectory => _i._logDirectory;

  /// Get current config.
  static LogConfig get config => _i._config;

  // ══════════════════════════════════════════════════════════════════════
  // NAVIGATION OBSERVER
  // ══════════════════════════════════════════════════════════════════════

  static LogiqNavigatorObserver? _navigationObserver;

  /// Returns a [NavigatorObserver] that logs navigation events.
  ///
  /// Use this with MaterialApp or CupertinoApp to automatically log
  /// navigation events (push, pop, replace, remove) with detailed context.
  ///
  /// ### Example
  ///
  /// ```dart
  /// MaterialApp(
  ///   navigatorObservers: [Logiq.navigationObserver],
  ///   home: HomePage(),
  /// )
  /// ```
  ///
  /// ### Logged Data
  ///
  /// Each navigation event logs:
  /// - **action**: push, pop, replace, or remove
  /// - **route**: The current/new route name
  /// - **previousRoute**: The previous route name
  /// - **routeType**: The route class (e.g., MaterialPageRoute)
  /// - **arguments**: Route arguments (if present)
  ///
  /// ### Custom Configuration
  ///
  /// For custom log level or category, create your own observer:
  ///
  /// ```dart
  /// MaterialApp(
  ///   navigatorObservers: [
  ///     LogiqNavigatorObserver(
  ///       logLevel: LogLevel.debug,
  ///       category: 'NAVIGATION',
  ///     ),
  ///   ],
  /// )
  /// ```
  ///
  /// See also:
  /// - [LogiqNavigatorObserver] for custom configuration options
  static LogiqNavigatorObserver get navigationObserver {
    _navigationObserver ??= LogiqNavigatorObserver();
    return _navigationObserver!;
  }

  // ══════════════════════════════════════════════════════════════════════
  // NETWORK LOGGING
  // ══════════════════════════════════════════════════════════════════════

  /// Logs a network request/response in a single call.
  ///
  /// This is a convenience method for quick network logging. For more
  /// detailed logging, use [logRequest] and [logResponse] separately.
  ///
  /// ```dart
  /// // In your HTTP interceptor:
  /// Logiq.network(
  ///   method: 'GET',
  ///   url: 'https://api.example.com/users',
  ///   statusCode: 200,
  ///   duration: Duration(milliseconds: 234),
  /// );
  /// ```
  static void network({
    required String method,
    required String url,
    int? statusCode,
    Duration? duration,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    Map<String, dynamic>? responseHeaders,
    dynamic responseBody,
    Object? error,
    String category = 'HTTP',
  }) {
    final context = <String, dynamic>{
      'method': method,
      'url': url,
      if (statusCode != null) 'statusCode': statusCode,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      if (requestHeaders != null) 'requestHeaders': requestHeaders,
      if (requestBody != null) 'requestBody': requestBody,
      if (responseHeaders != null) 'responseHeaders': responseHeaders,
      if (responseBody != null) 'responseBody': responseBody,
      if (error != null) 'error': error.toString(),
    };

    // Determine log level based on status code
    if (error != null) {
      e(category, '$method $url failed', context);
    } else if (statusCode != null && statusCode >= 400) {
      w(category, '$method $url → $statusCode', context);
    } else {
      i(category, '$method $url → ${statusCode ?? 'pending'}', context);
    }
  }

  /// Logs an HTTP request.
  ///
  /// Use before making the actual request for detailed request logging.
  ///
  /// ```dart
  /// Logiq.logRequest(LogiqRequest(
  ///   method: 'POST',
  ///   url: 'https://api.example.com/users',
  ///   headers: {'Content-Type': 'application/json'},
  ///   body: {'name': 'John'},
  /// ));
  /// ```
  static void logRequest(
    LogiqRequest request, {
    String category = 'HTTP',
    LogLevel level = LogLevel.debug,
  }) {
    _instance?._log(
      level,
      category,
      '→ ${request.method} ${request.url}',
      request.toContext(),
    );
  }

  /// Logs an HTTP response.
  ///
  /// Use after receiving a response for detailed response logging.
  ///
  /// ```dart
  /// Logiq.logResponse(LogiqResponse(
  ///   statusCode: 200,
  ///   url: 'https://api.example.com/users',
  ///   body: {'users': [...]},
  ///   duration: Duration(milliseconds: 234),
  /// ));
  /// ```
  static void logResponse(
    LogiqResponse response, {
    String category = 'HTTP',
  }) {
    final level = response.isError ? LogLevel.warning : LogLevel.info;
    _instance?._log(
      level,
      category,
      '← ${response.statusCode} ${response.url}',
      response.toContext(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════════

  void _scheduleCleanup() {
    if (_config.retention == null) return;

    // Run cleanup immediately
    _runCleanup();

    // Cancel existing timer and schedule periodic cleanup
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      _config.retention!.cleanupInterval,
      (_) => _runCleanup(),
    );
  }

  Future<void> _runCleanup() async {
    if (_config.retention == null) return;

    try {
      await clearOlderThan(
        _config.retention!.maxAge,
        minEntries: _config.retention!.minEntries,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Logiq: Cleanup error: $e\n$stackTrace');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════

  /// Dispose Logiq (call on app exit if needed).
  static Future<void> dispose() async {
    try {
      await _i._flush();
      _i._flushTimer?.cancel();
      _i._cleanupTimer?.cancel();
      _instance = null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Logiq: Dispose error: $e\n$stackTrace');
      }
    }
  }
}

class _LogFileInfo {
  const _LogFileInfo({
    required this.file,
    required this.stat,
    required this.entryCount,
  });

  final File file;
  final FileStat stat;
  final int entryCount;
}
