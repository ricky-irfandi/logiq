import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        RedactionPattern.creditCard,
      ],
      sinks: [
        const ConsoleSink(useColors: true),
      ],
      contextProviders: [
        () => {'appVersion': '1.0.0'},
      ],
      // ✨ Category Tabs for organized log viewing
      debugViewer: const DebugViewerConfig(
        enabled: true,
        tabs: [
          DebugTab(
            name: 'Network',
            categories: ['API', 'HTTP', 'Socket'],
            icon: Icons.wifi,
          ),
          DebugTab(
            name: 'Database',
            categories: ['DB', 'SQL', 'Cache'],
            icon: Icons.storage,
          ),
          DebugTab(
            name: 'Auth',
            categories: ['Auth', 'Login', 'Session'],
            icon: Icons.lock,
          ),
          DebugTab(
            name: 'UI',
            categories: ['UI', 'Navigation'],
            icon: Icons.widgets,
          ),
        ],
      ),
    ),
  );

  Logiq.i('APP', 'Application started');

  runApp(const LogiqDemoApp());
}

// ============================================================================
// THEME COLORS
// ============================================================================

class AppColors {
  // Primary gradient
  static const primary = Color(0xFF007AFF);
  static const primaryLight = Color(0xFF5AC8FA);
  static const primaryShadow = Color(0x4D007AFF); // 0.3 opacity

  // Background
  static const background = Color(0xFFF2F2F7);
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xFFF9F9FB);

  // Text
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF8E8E93);

  // Accent colors
  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const purple = Color(0xFFAF52DE);
  static const teal = Color(0xFF5AC8FA);
  static const indigo = Color(0xFF5856D6);

  // Pre-computed opacity colors
  static const shadowLight = Color(0x0A000000); // black 0.04
  static const shadowMedium = Color(0x1A000000); // black 0.1
  static const divider = Color(0x0F000000); // black 0.06
  static const greenLight = Color(0x2634C759); // green 0.15
  static const tealLight = Color(0x265AC8FA); // teal 0.15
}

// Extension for dynamic color opacity without deprecation warnings
extension ColorOpacity on Color {
  Color withOpacityValue(double opacity) {
    return Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), opacity);
  }
}

class LogiqDemoApp extends StatelessWidget {
  const LogiqDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logiq Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const HomePage(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logiq.showDebugButton(context);
    });
  }

  void _log(void Function() logFn) {
    HapticFeedback.lightImpact();
    logFn();
    setState(() => _logCount++);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Hero Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatsCard(),
                    const SizedBox(height: 28),
                    _buildSection(
                      title: 'Network',
                      subtitle: 'API, HTTP & Socket logs',
                      icon: Icons.wifi_rounded,
                      color: AppColors.primary,
                      buttons: [
                        _LogItem(
                            'GET',
                            AppColors.green,
                            () => _log(() => Logiq.network(
                                  method: 'GET',
                                  url: 'https://api.example.com/users',
                                  statusCode: 200,
                                  duration: const Duration(milliseconds: 234),
                                  responseBody: {
                                    'users': [
                                      {'id': 1, 'name': 'John'},
                                      {'id': 2, 'name': 'Jane'},
                                    ],
                                  },
                                ))),
                        _LogItem(
                            'POST',
                            AppColors.primary,
                            () => _log(() => Logiq.network(
                                  method: 'POST',
                                  url: 'https://api.example.com/users',
                                  statusCode: 201,
                                  duration: const Duration(milliseconds: 456),
                                  requestBody: {
                                    'name': 'John',
                                    'email': 'john@example.com'
                                  },
                                  responseBody: {'id': 123, 'name': 'John'},
                                ))),
                        _LogItem(
                            'Error',
                            AppColors.red,
                            () => _log(() => Logiq.network(
                                  method: 'GET',
                                  url: 'https://api.example.com/users/999',
                                  statusCode: 404,
                                  responseBody: {'error': 'User not found'},
                                ))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Database',
                      subtitle: 'DB, SQL & Cache operations',
                      icon: Icons.storage_rounded,
                      color: AppColors.purple,
                      buttons: [
                        _LogItem(
                            'Query',
                            AppColors.purple,
                            () => _log(() => Logiq.i(
                                'DB', 'SELECT * FROM users', {'rows': 42}))),
                        _LogItem(
                            'SQL Error',
                            AppColors.red,
                            () => _log(() => Logiq.e(
                                'SQL', 'Syntax error', {'query': '...'}))),
                        _LogItem(
                            'Cache',
                            AppColors.orange,
                            () => _log(() => Logiq.v(
                                'Cache', 'Hit for key', {'key': 'user_123'}))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Authentication',
                      subtitle: 'Login, Session & Auth events',
                      icon: Icons.lock_rounded,
                      color: AppColors.indigo,
                      buttons: [
                        _LogItem(
                            'Login',
                            AppColors.green,
                            () => _log(() => Logiq.i(
                                'Auth', 'User logged in', {'userId': '123'}))),
                        _LogItem(
                            'Session',
                            AppColors.teal,
                            () => _log(() => Logiq.d(
                                'Session', 'Refreshed', {'expires': '1h'}))),
                        _LogItem(
                            'Failed',
                            AppColors.red,
                            () => _log(() => Logiq.w('Login',
                                'Invalid credentials', {'attempts': 3}))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'UI Events',
                      subtitle: 'Navigation & render logs',
                      icon: Icons.widgets_rounded,
                      color: AppColors.orange,
                      buttons: [
                        _LogItem('Page View', AppColors.orange,
                            () => _log(() => Logiq.i('UI', 'HomePage viewed'))),
                        _LogItem(
                            'Navigate',
                            AppColors.primary,
                            () => _log(
                                () => Logiq.d('Navigation', 'Push /details'))),
                        _LogItem(
                            'Nested',
                            AppColors.indigo,
                            () => _log(() => Logiq.i(
                                  'API',
                                  'Complex response received',
                                  {
                                    'user': {
                                      'id': 12345,
                                      'name': 'John Doe',
                                      'email': 'john@example.com',
                                      'profile': {
                                        'avatar':
                                            'https://example.com/avatar.jpg',
                                        'bio': 'Flutter developer',
                                        'settings': {
                                          'theme': 'dark',
                                          'notifications': true,
                                          'language': 'en',
                                        },
                                      },
                                      'roles': ['admin', 'editor', 'viewer'],
                                    },
                                    'metadata': {
                                      'timestamp': '2025-12-16T09:45:00Z',
                                      'version': '2.1.0',
                                      'requestId': 'req_abc123xyz',
                                    },
                                    'items': [
                                      {
                                        'id': 1,
                                        'name': 'Item One',
                                        'price': 19.99
                                      },
                                      {
                                        'id': 2,
                                        'name': 'Item Two',
                                        'price': 29.99
                                      },
                                      {
                                        'id': 3,
                                        'name': 'Item Three',
                                        'price': 39.99
                                      },
                                    ],
                                    'pagination': {
                                      'page': 1,
                                      'limit': 10,
                                      'total': 156,
                                      'hasMore': true,
                                    },
                                  },
                                ))),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildActionsCard(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DEMO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Logiq',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'Zero-impact logging for Flutter',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Logiq.openViewer(context);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.primaryShadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.bug_report_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.greenLight,
                  AppColors.tealLight,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.analytics_rounded,
                color: AppColors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_logCount',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Logs created this session',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<_LogItem> buttons,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacityValue(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: buttons.map((item) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: buttons.last == item ? 0 : 10,
                  ),
                  child: GestureDetector(
                    onTap: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: item.color.withOpacityValue(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.color.withOpacityValue(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.visibility_rounded,
            label: 'Open Log Viewer',
            color: AppColors.primary,
            onTap: () => Logiq.openViewer(context),
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.analytics_rounded,
            label: 'Show Statistics',
            color: AppColors.green,
            onTap: () => _showStats(),
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.download_rounded,
            label: 'Export Logs',
            color: AppColors.purple,
            onTap: () => _exportLogs(),
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.sync_rounded,
            label: 'Force Flush',
            color: AppColors.orange,
            onTap: () => _flushLogs(),
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.delete_rounded,
            label: 'Clear All Logs',
            color: AppColors.red,
            onTap: () => _clearLogs(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showStats() async {
    HapticFeedback.mediumImpact();
    final stats = await Logiq.getStats();
    if (!mounted) return;
    _showDialog('Statistics', stats.toString());
  }

  Future<void> _exportLogs() async {
    HapticFeedback.mediumImpact();
    try {
      final result =
          await Logiq.export(compress: true, includeDeviceInfo: true);
      if (!mounted) return;
      _showDialog('Export Complete', '${result.entryCount} entries exported');
    } catch (e) {
      if (!mounted) return;
      _showDialog('Export Failed', e.toString());
    }
  }

  Future<void> _flushLogs() async {
    HapticFeedback.mediumImpact();
    await Logiq.flush();
    if (!mounted) return;
    _showDialog('Flushed', 'Logs written to disk');
  }

  Future<void> _clearLogs() async {
    HapticFeedback.mediumImpact();
    await Logiq.clear();
    setState(() => _logCount = 0);
    if (!mounted) return;
    _showDialog('Cleared', 'All logs deleted');
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogItem {
  final String label;
  final Color color;
  final VoidCallback onTap;

  _LogItem(this.label, this.color, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacityValue(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 70),
      color: AppColors.divider,
    );
  }
}
