# Logiq

**Zero-impact, fire-and-forget local logging system for Flutter**

[![Pub Version](https://img.shields.io/pub/v/logiq)](https://pub.dev/packages/logiq)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Logiq is an enterprise-grade logging solution designed for Flutter apps with a focus on **zero UI impact**. All heavy operations are offloaded to isolates, ensuring your logging never blocks the main thread.

## ✨ Features

- **⚡ Zero Impact** - Log calls return instantly (~0.001ms), heavy work happens in isolates
- **🔥 Fire & Forget** - Just call `Logiq.i()`, we handle the rest
- **🔒 Enterprise Security** - AES-256-GCM encryption and PII redaction
- **📦 Multiple Formats** - PlainText, JSON, Compact JSON, CSV, or custom
- **🔄 Smart Rotation** - Multi-file or single-file strategies
- **📊 Debug UI** - Built-in log viewer with search and filters
- **📤 Export** - GZip compressed exports with device info
- **🎯 Session Tracking** - Correlate logs across sessions
- **💾 Auto-Cleanup** - Retention policies for old logs
- **🎨 Customizable** - Formatters, sinks, hooks, and themes

## 📱 Platform Support

Logiq currently supports **iOS, Android, macOS, Windows, and Linux**.

**Web Platform:** Logiq is **not currently supported on web** due to its dependency on `dart:io` for file system operations. If you need web support, consider:
- Using console-only logging (ConsoleSink) for web builds
- Using conditional imports to swap implementations based on platform
- Contributing a web-compatible file storage implementation

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  logiq: ^1.0.0
```

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:logiq/logiq.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logiq
  await Logiq.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Log at different levels
    Logiq.v('APP', 'Verbose message');
    Logiq.d('APP', 'Debug message');
    Logiq.i('APP', 'Info message');
    Logiq.w('APP', 'Warning message');
    Logiq.e('APP', 'Error message');
    Logiq.f('APP', 'Fatal message');

    return MaterialApp(
      title: 'My App',
      home: const HomePage(),
    );
  }
}
```

### With Context

```dart
Logiq.i('BID', 'User placed bid', {
  'bidId': '12345',
  'amount': 1000,
  'currency': 'USD',
});
```

## 📖 Configuration

### Auto Configuration

```dart
// Automatically selects best config for debug/release
await Logiq.init(config: LogConfig.auto());
```

### Custom Configuration

```dart
await Logiq.init(
  config: LogConfig(
    minLevel: LogLevel.info,
    bufferSize: 500,
    flushInterval: const Duration(seconds: 30),
    format: FormatConfig.json(),
    rotation: RotationConfig.multiFile(
      maxFileSize: 2 * 1024 * 1024, // 2MB
      maxFiles: 3,
    ),
    redactionPatterns: [
      RedactionPattern.email,
      RedactionPattern.phone,
      RedactionPattern.creditCard,
    ],
    sinks: [
      const ConsoleSink(useColors: true),
    ],
    contextProviders: [
      () => {'appVersion': '1.0.0'},
    ],
    retention: const RetentionConfig(
      maxAge: Duration(days: 7),
      minEntries: 100,
    ),
    debugViewer: const DebugViewerConfig(enabled: true),
  ),
);
```

## 🎨 Formatting

### Available Formats

```dart
// Plain text (human-readable)
format: FormatConfig.plainText()

// JSON (NDJSON - one object per line)
format: FormatConfig.json()

// Compact JSON (shortened keys)
format: FormatConfig.compactJson()

// CSV (spreadsheet-compatible)
format: FormatConfig.csv()

// Custom formatter
format: FormatConfig.custom((entry) =>
  '${entry.timestamp} - ${entry.message}'
)
```

### Format Examples

**PlainText:**
```
[2025-01-15T10:30:45.123Z] [INFO   ] [BID] User placed bid {"bidId":"123"}
```

**JSON:**
```json
{"timestamp":"2025-01-15T10:30:45.123Z","level":"INFO","category":"BID","message":"User placed bid","context":{"bidId":"123"}}
```

**Compact JSON:**
```json
{"t":1705312245123,"l":2,"c":"BID","m":"User placed bid","x":{"bidId":"123"}}
```

## 🔒 Security

### PII Redaction

```dart
config: LogConfig(
  redactionPatterns: [
    RedactionPattern.email,          // Redacts email addresses
    RedactionPattern.phone,          // Redacts phone numbers
    RedactionPattern.phoneIndonesia, // Indonesian phone numbers
    RedactionPattern.creditCard,     // Credit card numbers
    RedactionPattern.ipAddress,      // IP addresses
    RedactionPattern.jwtToken,       // JWT tokens
    RedactionPattern.nopolIndonesia, // Indonesian vehicle plates
  ],
)
```

**Before:**
```
User email is john@example.com and phone is +1234567890
```

**After:**
```
User email is [EMAIL_REDACTED] and phone is [PHONE_REDACTED]
```

### Custom Redaction

```dart
// Add custom pattern
Logiq.addRedaction(
  RedactionPattern(
    name: 'api_key',
    pattern: RegExp(r'api_key=[a-zA-Z0-9]+'),
    replacement: 'api_key=[REDACTED]',
  ),
);
```

### Encryption

```dart
import 'dart:typed_data';

// With key provider (recommended)
encryption: EncryptionConfig.aes256(
  keyProvider: () async {
    // Key provider must return Uint8List
    final keyString = await secureStorage.read(key: 'log_key');
    return Uint8List.fromList(utf8.encode(keyString));
  },
)

// With static key (not recommended for production)
encryption: EncryptionConfig.aes256WithKey(
  key: EncryptionConfig.generateKey(), // Generates 32-byte Uint8List
)

// Generate a secure key
final secureKey = EncryptionConfig.generateKey(); // Returns Uint8List
```

## 🔄 File Rotation

### Multi-File Rotation

```dart
rotation: RotationConfig.multiFile(
  maxFileSize: 2 * 1024 * 1024, // 2MB
  maxFiles: 3,                   // Keep 3 backups
)
// Result: current.log → backup_1.log → backup_2.log → backup_3.log → deleted
```

### Single-File Rotation

```dart
rotation: RotationConfig.singleFile(
  maxFileSize: 5 * 1024 * 1024, // 5MB
  trimPercent: 25,               // Remove oldest 25% when full
)
```

## 📊 Debug UI

### Features

The built-in log viewer features:
- **Light/Dark Themes** - Tap the sun/moon icon to toggle 
- **Real-time Updates** - Auto-refresh every 15 seconds
- **Smart Filtering** - Filter by log level with refined chips
- **Search** - Quick search with glassmorphism design
- **Dual Views** - Card view or compact text view
- **Export & Share** - Native share sheet integration
- **Detail Sheets** - Tap any log to see full details with context

### Show Floating Debug Button

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Logiq.showDebugButton(context);
        });
        return child!;
      },
    );
  }
}
```

### Open Log Viewer

```dart
ElevatedButton(
  onPressed: () => Logiq.openViewer(context),
  child: const Text('View Logs'),
)
```

### Themes

The log viewer includes **two built-in themes**:

```dart
// Use dark theme (default)
debugViewer: const DebugViewerConfig(
  enabled: true,
  theme: LogViewerTheme.dark,
)

// Use light theme
debugViewer: const DebugViewerConfig(
  enabled: true,
  theme: LogViewerTheme.light,
)

// Custom theme
debugViewer: DebugViewerConfig(
  enabled: true,
  theme: LogViewerTheme(
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF1C1C1E),
    textColor: Color(0xFFF2F2F7),
    accentColor: Color(0xFF007AFF),
    // ... more customization
  ),
)
```

**Note:** Users can toggle between light and dark mode at runtime using the sun/moon button in the viewer.

## 📤 Export

```dart
// Export all logs
final result = await Logiq.export();
print('Exported ${result.entryCount} entries');
print('File: ${result.file.path}');
print('Compressed: ${result.compressionPercent.toStringAsFixed(1)}% saved');

// Export with options
final result = await Logiq.export(
  timeRange: const Duration(hours: 24), // Last 24 hours
  compress: true,                        // GZip compression
  includeDeviceInfo: true,               // Add device metadata
);
```

## 📈 Statistics

```dart
final stats = await Logiq.getStats();
print(stats.toString());
// Output:
// LogStats(
//   totalLogged: 1234
//   bufferedCount: 42
//   droppedCount: 0
//   writeFailures: 0
//   storageUsed: 1.23 MB
//   fileCount: 3
//   sessionId: sess_abc123
// )
```

## 🎯 Advanced Features

### Sensitive Mode

Pause logging during sensitive operations:

```dart
// Option 1: Explicit control
Logiq.enterSensitiveMode();
// ... sensitive operations ...
Logiq.exitSensitiveMode();

// Option 2: Automatic (recommended)
await Logiq.sensitive(() async {
  // Logs won't be recorded during this callback
  await processPayment();
});
```

### Runtime Configuration

```dart
// Change minimum level
Logiq.setMinLevel(LogLevel.error);

// Disable/enable logging
Logiq.setEnabled(false);

// Check status
if (Logiq.isEnabled) {
  // ...
}
```

### Context Providers

Auto-inject data into every log:

```dart
contextProviders: [
  () => {'appVersion': '1.0.0'},
  () => {'userId': currentUser.id},
  () => {'deviceId': deviceId},
]
```

### Hooks & Callbacks

```dart
hooks: LogHooks(
  onLog: (entry) => print('Logged: ${entry.message}'),
  onFlush: (count) => print('Flushed $count entries'),
  onRotate: () => print('Log file rotated'),
  onError: (error, stackTrace) => print('Error: $error'),
)
```

### Custom Sinks

```dart
sinks: [
  const ConsoleSink(useColors: true),
  CustomSink(
    onWrite: (entry) {
      // Send to external service
      analyticsService.track(entry);
    },
  ),
]
```

### Manual Flush

```dart
// Force write buffer to disk
await Logiq.flush();
```

### Cleanup

```dart
// Clear all logs
await Logiq.clear();

// Clear logs older than 7 days
await Logiq.clearOlderThan(const Duration(days: 7));
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              MAIN ISOLATE (UI Thread)           │
│                                                 │
│  Logiq.i('BID', 'User placed bid') ⚡ INSTANT  │
│           ↓                                     │
│  Ring Buffer (500 entries) ← Add entry         │
│           ↓                                     │
│  [Every 30s OR buffer full OR critical log]    │
│           ↓                                     │
│  compute(FileWriter.writeEntries, params)      │
└─────────────────────┬───────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         FILE WRITER ISOLATE (Background)        │
│                                                 │
│  1. Format logs (JSON/CSV/etc)                 │
│  2. Redact PII (emails, phones, etc)           │
│  3. Encrypt (AES-256-GCM)                      │
│  4. Write to disk                               │
│  5. Rotate files if needed                      │
└─────────────────────────────────────────────────┘
```

## 📦 Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:logiq/logiq.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Logiq.init(
    config: LogConfig(
      minLevel: LogLevel.verbose,
      format: FormatConfig.json(),
      rotation: RotationConfig.multiFile(
        maxFileSize: 2 * 1024 * 1024,
        maxFiles: 3,
      ),
      encryption: EncryptionConfig.aes256WithKey(
        key: EncryptionConfig.generateKey(),
      ),
      redactionPatterns: [
        RedactionPattern.email,
        RedactionPattern.phone,
        RedactionPattern.creditCard,
      ],
      sinks: [
        const ConsoleSink(useColors: true),
      ],
      contextProviders: [
        () => {'appVersion': '1.0.0'},
      ],
      retention: const RetentionConfig(
        maxAge: Duration(days: 7),
        cleanupInterval: Duration(hours: 6),
      ),
      hooks: LogHooks(
        onError: (error, stackTrace) {
          // Handle internal errors
        },
      ),
      debugViewer: const DebugViewerConfig(enabled: true),
    ),
  );

  Logiq.i('APP', 'Application started');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: const HomePage(),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Logiq.showDebugButton(context);
        });
        return child!;
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Log page view
    Logiq.i('NAVIGATION', 'HomePage viewed');

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Logiq.i('BUTTON', 'Button pressed');
            Logiq.openViewer(context);
          },
          child: const Text('View Logs'),
        ),
      ),
    );
  }
}
```

## 🎯 Best Practices

1. **Initialize Early** - Call `Logiq.init()` before `runApp()`
2. **Use Categories** - Group related logs with meaningful categories
3. **Add Context** - Include relevant data in the context map
4. **Redact PII** - Always configure redaction patterns for production
5. **Set Min Level** - Use `LogLevel.info` or higher in production
6. **Monitor Storage** - Check `getStats()` to track disk usage
7. **Export Regularly** - Set up periodic exports for analysis
8. **Handle Errors Silently** - Logiq never crashes your app

## 📄 API Reference

### Logging Methods

- `Logiq.v(category, message, [context])` - Verbose
- `Logiq.d(category, message, [context])` - Debug
- `Logiq.i(category, message, [context])` - Info
- `Logiq.w(category, message, [context])` - Warning
- `Logiq.e(category, message, [context])` - Error
- `Logiq.f(category, message, [context])` - Fatal

### Management

- `Logiq.init({config})` - Initialize Logiq
- `Logiq.flush()` - Force flush to disk
- `Logiq.clear()` - Clear all logs
- `Logiq.clearOlderThan(duration)` - Clear old logs
- `Logiq.getStats()` - Get statistics
- `Logiq.export({options})` - Export logs
- `Logiq.dispose()` - Cleanup on app exit

### Configuration

- `Logiq.setMinLevel(level)` - Change min level
- `Logiq.setEnabled(bool)` - Enable/disable logging
- `Logiq.addRedaction(pattern)` - Add redaction pattern
- `Logiq.enterSensitiveMode()` - Pause logging
- `Logiq.exitSensitiveMode()` - Resume logging
- `Logiq.sensitive(callback)` - Execute with logging paused

### UI

- `Logiq.showDebugButton(context)` - Show floating button
- `Logiq.hideDebugButton()` - Hide floating button
- `Logiq.openViewer(context)` - Open log viewer

### Properties

- `Logiq.isEnabled` - Check if logging is enabled
- `Logiq.logDirectory` - Get log directory path
- `Logiq.config` - Get current configuration

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Issues

If you encounter any issues or have suggestions, please file them in the [GitHub Issues](https://github.com/ricky-irfandi/logiq/issues).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed changelog.

## 🙏 Acknowledgments

- Built with ❤️ for the Flutter community
- Powered by `pointycastle` for encryption
- Uses `path_provider` for file access
- Compression via `archive` package

---

**Made with ❤️ by [Ricky-Irfandi](https://github.com/ricky-irfandi)**