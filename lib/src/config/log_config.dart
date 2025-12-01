import 'package:flutter/foundation.dart';

import '../context/context_provider.dart';
import '../core/log_level.dart';
import '../hooks/log_hooks.dart';
import '../security/redaction_pattern.dart';
import '../sink/log_sink.dart';
import 'debug_viewer_config.dart';
import 'encryption_config.dart';
import 'format_config.dart';
import 'retention_config.dart';
import 'rotation_config.dart';

/// Main configuration for Logiq.
class LogConfig {
  const LogConfig({
    this.minLevel = LogLevel.verbose,
    this.enabled = true,
    this.bufferSize = 500,
    this.flushInterval = const Duration(seconds: 30),
    this.format = const FormatConfig(),
    this.rotation = const RotationConfig(),
    this.encryption,
    this.redactionPatterns = const [],
    this.sinks = const [],
    this.contextProviders = const [],
    this.retention,
    this.hooks,
    this.debugViewer = const DebugViewerConfig(),
    this.directory,
  });

  /// Create config optimized for release builds.
  factory LogConfig.release() => const LogConfig(
        minLevel: LogLevel.info,
        flushInterval: Duration(seconds: 30),
        debugViewer: DebugViewerConfig(enabled: false),
      );

  /// Create config optimized for debug builds.
  factory LogConfig.debug() => const LogConfig(
        minLevel: LogLevel.verbose,
        flushInterval: Duration(seconds: 10),
        debugViewer: DebugViewerConfig(enabled: true),
      );

  /// Create config based on current build mode.
  factory LogConfig.auto() =>
      kDebugMode ? LogConfig.debug() : LogConfig.release();

  /// Create config optimized for production with security features.
  factory LogConfig.production({
    EncryptionConfig? encryption,
    List<RedactionPattern>? redactionPatterns,
    RetentionConfig? retention,
  }) =>
      LogConfig(
        minLevel: LogLevel.info,
        flushInterval: const Duration(seconds: 30),
        encryption: encryption,
        redactionPatterns: redactionPatterns ?? RedactionPattern.defaults,
        debugViewer: const DebugViewerConfig(enabled: false),
        retention:
            retention ?? const RetentionConfig(maxAge: Duration(days: 7)),
      );

  /// Minimum log level to record.
  final LogLevel minLevel;

  /// Whether logging is enabled.
  final bool enabled;

  /// Maximum entries in memory buffer before auto-flush.
  final int bufferSize;

  /// Interval for automatic buffer flush.
  final Duration flushInterval;

  /// Log format configuration.
  final FormatConfig format;

  /// File rotation configuration.
  final RotationConfig rotation;

  /// Encryption configuration (null = no encryption).
  final EncryptionConfig? encryption;

  /// PII redaction patterns.
  final List<RedactionPattern> redactionPatterns;

  /// Output sinks (file, console, custom).
  final List<LogSink> sinks;

  /// Providers for auto-injected context.
  final List<ContextProvider> contextProviders;

  /// Log retention/cleanup policy.
  final RetentionConfig? retention;

  /// Event hooks/callbacks.
  final LogHooks? hooks;

  /// Debug UI configuration.
  final DebugViewerConfig debugViewer;

  /// Custom log directory (null = default app directory).
  final String? directory;

  /// Create a copy with modified fields.
  LogConfig copyWith({
    LogLevel? minLevel,
    bool? enabled,
    int? bufferSize,
    Duration? flushInterval,
    FormatConfig? format,
    RotationConfig? rotation,
    EncryptionConfig? encryption,
    List<RedactionPattern>? redactionPatterns,
    List<LogSink>? sinks,
    List<ContextProvider>? contextProviders,
    RetentionConfig? retention,
    LogHooks? hooks,
    DebugViewerConfig? debugViewer,
    String? directory,
  }) {
    return LogConfig(
      minLevel: minLevel ?? this.minLevel,
      enabled: enabled ?? this.enabled,
      bufferSize: bufferSize ?? this.bufferSize,
      flushInterval: flushInterval ?? this.flushInterval,
      format: format ?? this.format,
      rotation: rotation ?? this.rotation,
      encryption: encryption ?? this.encryption,
      redactionPatterns: redactionPatterns ?? this.redactionPatterns,
      sinks: sinks ?? this.sinks,
      contextProviders: contextProviders ?? this.contextProviders,
      retention: retention ?? this.retention,
      hooks: hooks ?? this.hooks,
      debugViewer: debugViewer ?? this.debugViewer,
      directory: directory ?? this.directory,
    );
  }
}
