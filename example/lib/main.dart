import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logiq/logiq.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Logiq.init(
    config: LogConfig(
      minLevel: LogLevel.verbose,
      format: const FormatConfig.json(),
      rotation: RotationConfig.multiFile(maxFileSize: 2 * 1024 * 1024),
      encryption: EncryptionConfig.aes256(
        keyProvider: () async {
          return Uint8List.fromList(
            utf8.encode('0123456789ABCDEF0123456789ABCDEF'),
          );
        },
      ),
      redactionPatterns: [
        RedactionPattern.email,
        RedactionPattern.phone,
      ],
      sinks: [
        const ConsoleSink(useColors: true),
      ],
      contextProviders: [
        () => {'appVersion': '1.0.0'},
      ],
      debugViewer: const DebugViewerConfig(enabled: true),
    ),
  );

  // Log app start
  Logiq.i('APP', 'Application started');

  runApp(MaterialApp(
    title: 'Logiq Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
    ),
    home: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logiq Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
      builder: (context, child) {
        // Show debug button after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Logiq.showDebugButton(context);
        });
        return child!;
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _logCount = 0;

  void _logMessage(void Function() logFn, String label) {
    logFn();
    setState(() => _logCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logiq Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => Logiq.openViewer(context),
            tooltip: 'Open Log Viewer',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log Examples',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Logs created: $_logCount'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Log Levels:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.v('UI', 'This is a verbose log message'),
              'Verbose',
            ),
            child: const Text('Log Verbose'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.d('UI', 'Debug log with context', {'data': 123}),
              'Debug',
            ),
            child: const Text('Log Debug'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.i('UI', 'Info log message'),
              'Info',
            ),
            child: const Text('Log Info'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.w('UI', 'Warning: something might be wrong'),
              'Warning',
            ),
            child: const Text('Log Warning'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.e(
                  'UI', 'Error occurred', {'error': 'Something went wrong'}),
              'Error',
            ),
            child: const Text('Log Error'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.f('UI', 'Fatal error - system critical'),
              'Fatal',
            ),
            child: const Text('Log Fatal'),
          ),
          const SizedBox(height: 24),
          const Text(
            'PII Redaction Demo:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _logMessage(
              () => Logiq.i(
                'REDACTION',
                'User email is john@example.com and phone is +1234567890',
              ),
              'PII (will be redacted)',
            ),
            child: const Text('Log with PII (Email & Phone)'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Management:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            onPressed: () => Logiq.openViewer(context),
            label: const Text('Open Log Viewer'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.info),
            onPressed: () async {
              final stats = await Logiq.getStats();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Statistics'),
                  content: Text(stats.toString()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            label: const Text('Show Statistics'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting logs...')),
                );
                final result = await Logiq.export(
                  compress: true,
                  includeDeviceInfo: true,
                );
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Export Complete'),
                    content: Text(result.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            },
            label: const Text('Export Logs'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await Logiq.flush();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs flushed to disk')),
              );
            },
            label: const Text('Force Flush'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await Logiq.clear();
              setState(() => _logCount = 0);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All logs cleared')),
              );
            },
            label: const Text('Clear All Logs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sensitive Mode Demo:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              // Logs won't be recorded during sensitive operations
              await Logiq.sensitive(() async {
                Logiq.i('SENSITIVE', 'This will NOT be logged');
                await Future.delayed(const Duration(milliseconds: 500));
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sensitive operation complete (not logged)'),
                ),
              );
            },
            child: const Text('Execute Sensitive Operation'),
          ),
        ],
      ),
    );
  }
}
