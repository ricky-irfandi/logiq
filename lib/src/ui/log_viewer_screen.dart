import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config/format_config.dart';
import '../core/log_entry.dart';
import '../core/log_level.dart';
import '../core/logiq.dart';
import '../format/csv_formatter.dart';
import '../security/log_encryptor.dart';
import 'log_viewer_theme.dart';

/// Extension to replace deprecated withOpacity with Color.fromRGBO.
/// This avoids precision loss and is compatible with older Flutter SDKs.
extension _ColorOpacity on Color {
  Color withOpacityCompat(double opacity) {
    // Using red/green/blue for Flutter 3.24 compatibility
    // ignore: deprecated_member_use
    return Color.fromRGBO(red, green, blue, opacity);
  }
}

/// Apple-inspired log viewer with elegant UI and smooth animations.
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({
    super.key,
    required this.logDirectory,
    this.theme = const LogViewerTheme(),
  });

  final String logDirectory;
  final LogViewerTheme theme;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with TickerProviderStateMixin {
  final List<LogEntry> _logEntries = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  static const int _maxEntries = 1000;

  bool _isLoading = true;
  String? _error;
  final Set<LogLevel> _selectedLevels = LogLevel.values.toSet();
  String _searchQuery = '';
  final bool _autoScroll = true;
  bool _compactView = true;
  bool _isDarkMode = false;
  Timer? _refreshTimer;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadLogs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadLogs(showLoading: false);
    });
  }

  Future<void> _loadLogs({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final logFormat = Logiq.config.format.type;
      LogEncryptor? encryptor;
      try {
        final encryptionConfig = Logiq.config.encryption;
        if (encryptionConfig != null && encryptionConfig.enabled) {
          final key = await encryptionConfig.getKey();
          encryptor = LogEncryptor(key);
        }
      } catch (_) {
        encryptor = null;
      }

      final dir = Directory(widget.logDirectory);
      if (!await dir.exists()) {
        setState(() {
          _error = 'Log directory not found';
          _isLoading = false;
        });
        return;
      }

      final entries = <LogEntry>[];

      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.log')) {
          try {
            final content = await file.readAsString();
            final lines = content.split('\n').where((l) => l.trim().isNotEmpty);

            for (final line in lines) {
              final entry = _parseLogLine(
                line,
                format: logFormat,
                encryptor: encryptor,
              );
              if (entry != null) entries.add(entry);
            }
          } catch (e) {
            continue;
          }
        }
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final limitedEntries = entries.take(_maxEntries).toList();

      setState(() {
        _logEntries.clear();
        _logEntries.addAll(limitedEntries);
        _isLoading = false;
      });

      _fadeController.forward(from: 0);

      if (showLoading && _autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }

      encryptor?.dispose();
    } catch (e) {
      if (showLoading) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  LogEntry? _parseLogLine(
    String line, {
    required LogFormat format,
    LogEncryptor? encryptor,
  }) {
    LogEntry? parsePayload(String payload) {
      switch (format) {
        case LogFormat.json:
        case LogFormat.compactJson:
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            if (json.containsKey('timestamp')) {
              return LogEntry.fromJson(json);
            } else if (json.containsKey('t')) {
              return LogEntry.fromCompactJson(json);
            }
          } catch (_) {
            return null;
          }
          return null;
        case LogFormat.plainText:
          return _parsePlainText(payload);
        case LogFormat.csv:
          return _parseCsvLine(payload);
        case LogFormat.custom:
          return _parsePlainText(payload);
      }
    }

    final direct = parsePayload(line);
    if (direct != null) return direct;

    if (encryptor != null) {
      try {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          final cipherBytes = base64Decode(trimmed);
          final decrypted = encryptor.decrypt(cipherBytes);
          final decryptedEntry = parsePayload(decrypted);
          if (decryptedEntry != null) return decryptedEntry;
        }
      } catch (_) {}
    }

    return _parsePlainText(line);
  }

  LogEntry? _parsePlainText(String line) {
    try {
      final match = RegExp(
        r'^\[(.*?)\]\s+\[(.*?)\]\s+\[(.*?)\]\s+(.*)$',
      ).firstMatch(line);

      if (match == null) return null;

      final timestampStr = match.group(1)!;
      final levelStr = match.group(2)!.trim();
      final category = match.group(3)!.trim();
      var messageAndContext = match.group(4)!.trim();

      DateTime timestamp;
      try {
        timestamp = DateTime.parse(timestampStr);
      } catch (_) {
        timestamp = DateTime.now();
      }

      Map<String, dynamic>? context;
      final contextStart = messageAndContext.indexOf('{');
      if (contextStart != -1) {
        final messagePart = messageAndContext.substring(0, contextStart).trim();
        final contextPart = messageAndContext.substring(contextStart).trim();
        messageAndContext = messagePart;
        try {
          final decoded = jsonDecode(contextPart);
          if (decoded is Map<String, dynamic>) context = decoded;
        } catch (_) {}
      }

      final level = LogLevel.tryParse(levelStr.toLowerCase()) ?? LogLevel.info;

      return LogEntry(
        timestamp: timestamp,
        level: level,
        category: category,
        message: messageAndContext,
        context: context,
      );
    } catch (_) {
      return null;
    }
  }

  LogEntry? _parseCsvLine(String line) {
    try {
      if (line.trim() == CsvFormatter.header) return null;

      final cells = _splitCsvLine(line);
      if (cells.length < 6) return null;

      final timestampStr = cells[0];
      final levelStr = cells[1];
      final category = cells[2];
      final message = cells[3];
      final contextStr = cells[4];
      final sessionId = cells[5].isEmpty ? null : cells[5];

      DateTime timestamp;
      try {
        timestamp = DateTime.parse(timestampStr);
      } catch (_) {
        timestamp = DateTime.now();
      }

      Map<String, dynamic>? context;
      if (contextStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(contextStr);
          if (decoded is Map<String, dynamic>) context = decoded;
        } catch (_) {}
      }

      final level = LogLevel.tryParse(levelStr.toLowerCase()) ?? LogLevel.info;

      return LogEntry(
        timestamp: timestamp,
        level: level,
        category: category,
        message: message,
        context: context,
        sessionId: sessionId,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  List<LogEntry> get _filteredEntries {
    return _logEntries.where((entry) {
      if (!_selectedLevels.contains(entry.level)) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return entry.message.toLowerCase().contains(query) ||
            entry.category.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: theme.accentColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Console',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${_filteredEntries.length} entries • Live',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _buildIconButton(
            icon:
                _compactView ? Icons.view_agenda_outlined : Icons.list_rounded,
            onPressed: () => setState(() => _compactView = !_compactView),
          ),
          _buildIconButton(
            icon: Icons.ios_share_rounded,
            onPressed: _exportLogs,
          ),
          _buildIconButton(
            icon: _isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          _buildIconButton(
            icon: Icons.refresh_rounded,
            onPressed: () => _loadLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      onPressed: onPressed,
      child: Icon(icon, color: theme.accentColor, size: 22),
    );
  }

  Widget _buildSearchBar() {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.surfaceColor.withOpacityCompat(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: theme.secondaryTextColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.secondaryTextColor,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: LogLevel.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final level = LogLevel.values[index];
          final isSelected = _selectedLevels.contains(level);
          final color = theme.colorForLevel(level.value);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (isSelected) {
                  _selectedLevels.remove(level);
                } else {
                  _selectedLevels.add(level);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacityCompat(0.15)
                    : theme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? color.withOpacityCompat(0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacityCompat(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    level.name[0].toUpperCase() + level.name.substring(1),
                    style: TextStyle(
                      color:
                          isSelected ? color : widget.theme.secondaryTextColor,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    if (_isLoading) {
      return Center(
        child: CupertinoActivityIndicator(
          color: widget.theme.accentColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: () => _loadLogs(),
              child: Text(
                'Retry',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
          ],
        ),
      );
    }

    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: widget.theme.separatorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No Results' : 'No Logs',
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Logs will appear here',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _compactView
              ? _AppleCompactTile(
                  entry: entry,
                  theme: theme,
                  onTap: () => _showLogDetail(entry),
                )
              : _AppleLogCard(
                  entry: entry,
                  theme: theme,
                  onTap: () => _showLogDetail(entry),
                );
        },
      ),
    );
  }

  void _showLogDetail(LogEntry entry) {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AppleLogDetailSheet(
        entry: entry,
        theme: theme,
      ),
    );
  }

  Future<void> _exportLogs() async {
    final theme = _isDarkMode ? widget.theme : LogViewerTheme.light;
    final result = await showCupertinoModalPopup<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AppleExportSheet(theme: theme),
    );

    if (result == null) return;

    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.theme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: CupertinoActivityIndicator(color: theme.accentColor),
        ),
      ),
    );

    try {
      final exportResult = await Logiq.export(
        timeRange: result['timeRange'] as Duration?,
        compress: result['compress'] as bool? ?? true,
        includeDeviceInfo: result['includeDeviceInfo'] as bool? ?? true,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF30D158)),
              SizedBox(width: 8),
              Text('Export Complete'),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${exportResult.entryCount} entries\n'
              '${(exportResult.compressedSize / 1024).toStringAsFixed(1)} KB',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Copy Path'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportResult.file.path));
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Share'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Share.shareXFiles(
                  [XFile(exportResult.file.path)],
                  subject: 'Logiq Export',
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Export Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

// Apple-style log card
class _AppleLogCard extends StatelessWidget {
  const _AppleLogCard({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final LogEntry entry;
  final LogViewerTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorForLevel(entry.level.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.separatorColor, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacityCompat(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      entry.level.name.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.separatorColor.withOpacityCompat(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.category,
                        style: TextStyle(
                          color: theme.categoryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(entry.timestamp),
                      style: TextStyle(
                        color: theme.timestampColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  entry.message,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.context != null && entry.context!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 12,
                        color: theme.timestampColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.context!.length} fields',
                        style: TextStyle(
                          color: theme.timestampColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(timestamp.toLocal());
  }
}

// Compact tile
class _AppleCompactTile extends StatelessWidget {
  const _AppleCompactTile({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final LogEntry entry;
  final LogViewerTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorForLevel(entry.level.value);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.separatorColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('HH:mm:ss').format(entry.timestamp.toLocal()),
              style: TextStyle(
                color: theme.timestampColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 10),
            Text(
              entry.category,
              style: TextStyle(
                color: theme.categoryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(color: theme.textColor, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail sheet
class _AppleLogDetailSheet extends StatelessWidget {
  const _AppleLogDetailSheet({required this.entry, required this.theme});

  final LogEntry entry;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorForLevel(entry.level.value);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: theme.separatorColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.level.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: jsonEncode(entry.toJson())),
                      );
                      HapticFeedback.mediumImpact();
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      color: theme.accentColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.separatorColor, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailItem(
                    label: 'Category',
                    value: entry.category,
                    theme: theme,
                  ),
                  _DetailItem(
                    label: 'Time',
                    value: DateFormat('MMM dd, yyyy HH:mm:ss.SSS')
                        .format(entry.timestamp.toLocal()),
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Message',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    entry.message,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 15,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (entry.context != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Context',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(entry.context),
                        style: TextStyle(
                          color: theme.textColor,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Export sheet
class _AppleExportSheet extends StatefulWidget {
  const _AppleExportSheet({required this.theme});
  final LogViewerTheme theme;

  @override
  State<_AppleExportSheet> createState() => _AppleExportSheetState();
}

class _AppleExportSheetState extends State<_AppleExportSheet> {
  Duration? _timeRange;
  bool _compress = true;
  bool _includeDeviceInfo = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.theme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.theme.separatorColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Export Logs',
                  style: TextStyle(
                    color: widget.theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildOption(
                title: 'Time Range',
                trailing: Text(
                  _timeRange == null
                      ? 'All'
                      : _timeRange == const Duration(hours: 1)
                          ? '1 hour'
                          : _timeRange == const Duration(hours: 24)
                              ? '24 hours'
                              : '7 days',
                  style: TextStyle(color: widget.theme.secondaryTextColor),
                ),
                onTap: () => _showTimePicker(),
              ),
              _buildToggle(
                title: 'Compress',
                value: _compress,
                onChanged: (v) => setState(() => _compress = v),
              ),
              _buildToggle(
                title: 'Include Device Info',
                value: _includeDeviceInfo,
                onChanged: (v) => setState(() => _includeDeviceInfo = v),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: widget.theme.accentColor,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () {
                      Navigator.of(context).pop({
                        'timeRange': _timeRange,
                        'compress': _compress,
                        'includeDeviceInfo': _includeDeviceInfo,
                      });
                    },
                    child: const Text(
                      'Export',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: widget.theme.separatorColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(color: widget.theme.textColor, fontSize: 16),
            ),
            const Spacer(),
            trailing,
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: widget.theme.separatorColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: widget.theme.separatorColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(color: widget.theme.textColor, fontSize: 16),
          ),
          const Spacer(),
          CupertinoSwitch(
            value: value,
            activeTrackColor: widget.theme.accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showTimePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('All Logs'),
            onPressed: () {
              setState(() => _timeRange = null);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Last 1 Hour'),
            onPressed: () {
              setState(() => _timeRange = const Duration(hours: 1));
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Last 24 Hours'),
            onPressed: () {
              setState(() => _timeRange = const Duration(hours: 24));
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Last 7 Days'),
            onPressed: () {
              setState(() => _timeRange = const Duration(days: 7));
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
