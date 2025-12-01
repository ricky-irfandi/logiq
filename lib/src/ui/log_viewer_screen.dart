import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/log_entry.dart';
import '../core/log_level.dart';
import '../core/logiq.dart';
import '../config/format_config.dart';
import '../format/csv_formatter.dart';
import '../security/log_encryptor.dart';
import 'log_viewer_theme.dart';

/// Built-in log viewer screen with beautiful card-based UI and real-time updates.
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

class _LogViewerScreenState extends State<LogViewerScreen> {
  final List<LogEntry> _logEntries = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Limit to last N entries for low-end device performance
  static const int _maxEntries = 1000;

  bool _isLoading = true;
  String? _error;
  final Set<LogLevel> _selectedLevels = LogLevel.values.toSet();
  String _searchQuery = '';
  bool _autoScroll = true;
  bool _compactView = false; // Toggle between card and compact text view
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // Real-time updates every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
      // Determine active log format so we can parse lines appropriately.
      final logFormat = Logiq.config.format.type;
      // Try to obtain encryption key if encryption is enabled so we can
      // transparently read encrypted log lines in the viewer.
      LogEncryptor? encryptor;
      try {
        final encryptionConfig = Logiq.config.encryption;
        if (encryptionConfig != null && encryptionConfig.enabled) {
          final key = await encryptionConfig.getKey();
          encryptor = LogEncryptor(key);
        }
      } catch (_) {
        // If key retrieval or encryptor creation fails, fall back to
        // plain-text parsing without breaking the UI.
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

      // Load all log files
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
              if (entry != null) {
                entries.add(entry);
              }
            }
          } catch (e) {
            // Skip files that can't be read (e.g., being written)
            continue;
          }
        }
      }

      // Sort by timestamp (newest first for better UX)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Limit to max entries for performance on low-end devices
      final limitedEntries = entries.take(_maxEntries).toList();

      setState(() {
        _logEntries.clear();
        _logEntries.addAll(limitedEntries);
        _isLoading = false;
      });

      // Only auto-scroll on manual refresh, not on background updates
      if (showLoading && _autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0, // Scroll to top (newest)
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // Dispose encryptor after use to zero key material from memory.
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

  /// Parse log line - supports JSON, compact JSON, plain text, CSV, and
  /// their encrypted variants when encryption is enabled.
  LogEntry? _parseLogLine(
    String line, {
    required LogFormat format,
    LogEncryptor? encryptor,
  }) {
    // Helper to parse a single, already-decoded payload according to format.
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
          // Custom formatter can't be reliably reversed; fall back to plain text.
          return _parsePlainText(payload);
      }
    }

    // 1) Try parsing as-is (for non-encrypted logs).
    final direct = parsePayload(line);
    if (direct != null) return direct;

    // 2) Try decrypting base64-encoded ciphertext if encryptor is available.
    if (encryptor != null) {
      try {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          final cipherBytes = base64Decode(trimmed);
          final decrypted = encryptor.decrypt(cipherBytes);
          final decryptedEntry = parsePayload(decrypted);
          if (decryptedEntry != null) return decryptedEntry;
        }
      } catch (_) {
        // Decrypt or parse failed, fall through to final fallback.
      }
    }

    // 3) Final fallback: attempt plain text parse.
    return _parsePlainText(line);
  }

  /// Fallback parser for plain text logs
  LogEntry? _parsePlainText(String line) {
    try {
      // Expected format (from PlainTextFormatter):
      // [timestamp] [LEVEL] [CATEGORY] message {optional JSON context}
      // LEVEL is padded to width 7, e.g. [INFO   ], so allow trailing spaces.
      final match = RegExp(
        r'^\[(.*?)\]\s+\[(.*?)\]\s+\[(.*?)\]\s+(.*)$',
      ).firstMatch(line);

      if (match == null) return null;

      final timestampStr = match.group(1)!;
      final levelStr = match.group(2)!.trim();
      final category = match.group(3)!.trim();
      var messageAndContext = match.group(4)!.trim();

      // Parse timestamp (falls back to now on failure).
      DateTime timestamp;
      try {
        timestamp = DateTime.parse(timestampStr);
      } catch (_) {
        timestamp = DateTime.now();
      }

      // Try to split out JSON context at the end if present.
      Map<String, dynamic>? context;
      final contextStart = messageAndContext.indexOf('{');
      if (contextStart != -1) {
        final messagePart = messageAndContext.substring(0, contextStart).trim();
        final contextPart = messageAndContext.substring(contextStart).trim();
        messageAndContext = messagePart;
        try {
          final decoded = jsonDecode(contextPart);
          if (decoded is Map<String, dynamic>) {
            context = decoded;
          }
        } catch (_) {
          // If context JSON fails, keep message-only entry.
        }
      }

      final level =
          LogLevel.tryParse(levelStr.toLowerCase()) ?? LogLevel.info;

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

  /// Parser for CSV logs created by CsvFormatter.
  ///
  /// Expected schema:
  /// timestamp,level,category,message,context,sessionId
  LogEntry? _parseCsvLine(String line) {
    try {
      // Skip header row
      if (line.trim() == CsvFormatter.header) {
        return null;
      }

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
          if (decoded is Map<String, dynamic>) {
            context = decoded;
          }
        } catch (_) {
          // Ignore malformed context JSON.
        }
      }

      final level =
          LogLevel.tryParse(levelStr.toLowerCase()) ?? LogLevel.info;

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

  /// Minimal CSV splitter that understands quoted fields with commas.
  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
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
      // Filter by level
      if (!_selectedLevels.contains(entry.level)) {
        return false;
      }

      // Filter by search query
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
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.theme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to app',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Logs', style: TextStyle(fontSize: 20)),
            Text(
              'Real-time • ${_filteredEntries.length} entries',
              style: TextStyle(
                fontSize: 12,
                color: widget.theme.textColor.withValues(alpha: (0.6)),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_compactView ? Icons.view_agenda : Icons.view_list,
                color: Colors.white),
            tooltip: _compactView ? 'Card View' : 'Compact View',
            onPressed: () => setState(() => _compactView = !_compactView),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Export & Share Logs',
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => _loadLogs(),
          ),
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_top
                  : Icons.vertical_align_center,
              color: Colors.white,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: widget.theme.textColor),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(
                  color: widget.theme.textColor.withValues(
                    alpha: (0.5),
                  ),
                ),
                prefixIcon: Icon(Icons.search, color: widget.theme.textColor),
                filled: true,
                fillColor: widget.theme.textColor.withValues(alpha: (0.05)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Level filter chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: LogLevel.values.length,
              itemBuilder: (context, index) {
                final level = LogLevel.values[index];
                final isSelected = _selectedLevels.contains(level);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(level.name.toUpperCase()),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : widget.theme.colorForLevel(level.value),
                    ),
                    backgroundColor: widget.theme
                        .colorForLevel(level.value)
                        .withValues(alpha: (0.1)),
                    selectedColor: widget.theme.colorForLevel(level.value),
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLevels.add(level);
                        } else {
                          _selectedLevels.remove(level);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Log entries
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: widget.theme.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: widget.theme.textColor)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadLogs(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
              size: 64,
              color: widget.theme.textColor.withValues(alpha: (0.3)),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No matching logs' : 'No logs yet',
              style: TextStyle(
                color: widget.theme.textColor.withValues(alpha: (0.6)),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: _compactView
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        // Switch between compact and card view
        if (_compactView) {
          return _CompactLogTile(
            entry: entry,
            theme: widget.theme,
            onTap: () => _showLogDetail(entry),
          );
        } else {
          return _LogCard(
            entry: entry,
            theme: widget.theme,
            searchQuery: _searchQuery,
            onTap: () => _showLogDetail(entry),
          );
        }
      },
    );
  }

  void _showLogDetail(LogEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.theme.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log Details',
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy',
                      onPressed: () {
                        final text = jsonEncode(entry.toJson());
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          'Level',
                          entry.level.name.toUpperCase(),
                          widget.theme.colorForLevel(entry.level.value),
                        ),
                        _DetailRow('Category', entry.category, null),
                        _DetailRow(
                          'Time',
                          DateFormat('MMM dd, yyyy HH:mm:ss.SSS')
                              .format(entry.timestamp.toLocal()),
                          null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Message',
                          style: TextStyle(
                            color:
                                widget.theme.textColor.withValues(alpha: (0.6)),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          entry.message,
                          style: TextStyle(
                            color: widget.theme.textColor,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        if (entry.context != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Context',
                            style: TextStyle(
                              color: widget.theme.textColor
                                  .withValues(alpha: (0.6)),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.theme.textColor
                                  .withValues(alpha: (0.05)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(entry.context),
                              style: TextStyle(
                                color: widget.theme.textColor,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Export logs and show shareable file path
  Future<void> _exportLogs() async {
    // Show export options dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ExportDialog(),
    );

    if (result == null) return; // User cancelled

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Exporting logs...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Export using Logiq.export()
      final exportResult = await Logiq.export(
        timeRange: result['timeRange'] as Duration?,
        compress: result['compress'] as bool? ?? true,
        includeDeviceInfo: result['includeDeviceInfo'] as bool? ?? true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success with file info
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${exportResult.file.path.split('/').last}'),
              const SizedBox(height: 8),
              Text('Entries: ${exportResult.entryCount}'),
              Text(
                'Size: ${(exportResult.compressedSize / 1024).toStringAsFixed(1)} KB',
              ),
              if (exportResult.compressedSize < exportResult.originalSize)
                Text(
                  'Compressed: ${((1 - exportResult.compressedSize / exportResult.originalSize) * 100).toStringAsFixed(1)}%',
                ),
              const SizedBox(height: 16),
              const Text(
                'Send this file to your development team for debugging.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: exportResult.file.path),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File path copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Copy Path'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first

                // Share the file using native share sheet
                await Share.shareXFiles(
                  [XFile(exportResult.file.path)],
                  subject:
                      'Logiq Export - ${exportResult.file.path.split('/').last}',
                  text: 'Log export with ${exportResult.entryCount} entries',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show error
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Export Failed'),
            ],
          ),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
    super.dispose();
  }
}

/// Dialog for selecting export options
class _ExportDialog extends StatefulWidget {
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  Duration? _timeRange;
  bool _compress = true;
  bool _includeDeviceInfo = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Logs'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select options for log export:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Time range
          DropdownButtonFormField<Duration?>(
            value: _timeRange,
            decoration: const InputDecoration(
              labelText: 'Time Range',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All logs')),
              DropdownMenuItem(
                value: Duration(hours: 1),
                child: Text('Last 1 hour'),
              ),
              DropdownMenuItem(
                value: Duration(hours: 24),
                child: Text('Last 24 hours'),
              ),
              DropdownMenuItem(
                value: Duration(days: 7),
                child: Text('Last 7 days'),
              ),
            ],
            onChanged: (value) => setState(() => _timeRange = value),
          ),
          const SizedBox(height: 12),
          // Compress
          SwitchListTile(
            value: _compress,
            onChanged: (value) => setState(() => _compress = value),
            title: const Text('Compress (GZip)'),
            subtitle: const Text('Recommended for large logs'),
            contentPadding: EdgeInsets.zero,
          ),
          // Include device info
          SwitchListTile(
            value: _includeDeviceInfo,
            onChanged: (value) => setState(() => _includeDeviceInfo = value),
            title: const Text('Include Device Info'),
            subtitle: const Text('Platform, OS version, etc.'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop({
              'timeRange': _timeRange,
              'compress': _compress,
              'includeDeviceInfo': _includeDeviceInfo,
            });
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Export'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color? color;

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
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful, lightweight log card with Material 3 design
class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.entry,
    required this.theme,
    required this.searchQuery,
    required this.onTap,
  });

  final LogEntry entry;
  final LogViewerTheme theme;
  final String searchQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final levelColor = theme.colorForLevel(entry.level.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.textColor.withValues(alpha: (0.03)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: levelColor.withValues(alpha: (0.3)),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Level chip + Timestamp
              Row(
                children: [
                  // Level chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.level.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.textColor.withValues(alpha: (0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.category,
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: (0.8)),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Timestamp
                  Text(
                    _formatTimestamp(entry.timestamp),
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: (0.5)),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Message
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
              // Context indicator
              if (entry.context != null && entry.context!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.code,
                      size: 14,
                      color: theme.textColor.withValues(alpha: (0.5)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.context!.length} context fields',
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: (0.5)),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp.toLocal());
    }
  }
}

/// Compact text-based log tile for quick scanning
/// Format: [LEVEL] [CATEGORY] message
class _CompactLogTile extends StatelessWidget {
  const _CompactLogTile({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final LogEntry entry;
  final LogViewerTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final levelColor = theme.colorForLevel(entry.level.value);
    final timestamp = _formatCompactTimestamp(entry.timestamp);

    // Format: [12:34:56] [E] [API] Connection timeout
    // Single letter: V=Verbose, D=Debug, I=Info, W=Warning, E=Error, F=Fatal
    final levelText = _getLevelAbbreviation(entry.level);

    return InkWell(
      onTap: onTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: theme.fontFamily,
              fontSize: 13,
              height: 1.5,
            ),
            children: [
              // Timestamp
              TextSpan(
                text: '[$timestamp] ',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: (0.5)),
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Level (single letter)
              TextSpan(
                text: '[$levelText] ',
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Slightly larger for emphasis
                ),
              ),
              // Category
              TextSpan(
                text: '[${entry.category}] ',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: (0.7)),
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Message
              TextSpan(
                text: entry.message,
                style: TextStyle(
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLevelAbbreviation(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
      case LogLevel.fatal:
        return 'F';
    }
  }

  String _formatCompactTimestamp(DateTime timestamp) {
    return DateFormat('HH:mm:ss').format(timestamp.toLocal());
  }
}
