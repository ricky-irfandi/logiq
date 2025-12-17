import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/log_entry.dart';
import 'log_viewer_theme.dart';

/// Extension to replace deprecated withOpacity with Color.fromRGBO.
extension _ColorOpacity on Color {
  Color withOpacityCompat(double opacity) {
    // ignore: deprecated_member_use
    return Color.fromRGBO(red, green, blue, opacity);
  }
}

/// Full-screen detail page for network log entries.
class NetworkLogDetailScreen extends StatelessWidget {
  const NetworkLogDetailScreen({
    super.key,
    required this.entry,
    required this.theme,
  });

  final LogEntry entry;
  final LogViewerTheme theme;

  Map<String, dynamic> get _ctx => entry.context ?? {};
  String get _method => _ctx['method'] as String? ?? 'GET';
  String get _url => _ctx['url'] as String? ?? '';
  int? get _statusCode => _ctx['statusCode'] as int?;
  int? get _durationMs => _ctx['durationMs'] as int?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildGeneralSection(context),
                  const SizedBox(height: 10),
                  _buildRequestSection(context),
                  const SizedBox(height: 10),
                  _buildResponseSection(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final methodColor = _getMethodColor(_method);
    final statusColor = _getStatusColor(_statusCode);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Back + Method + Actions
          Row(
            children: [
              // Back button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Method badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      methodColor,
                      methodColor.withOpacityCompat(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: methodColor.withOpacityCompat(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  _method,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              // cURL button
              _ActionChip(
                icon: Icons.terminal_rounded,
                label: 'cURL',
                theme: theme,
                onTap: () => _copyCurl(context),
              ),
              const SizedBox(width: 8),
              // Copy All button
              _ActionChip(
                icon: Icons.copy_all_rounded,
                label: 'Copy',
                theme: theme,
                onTap: () => _copyAll(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // URL box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.separatorColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: theme.secondaryTextColor,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _url,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _CopyIconButton(
                  onTap: () => _copyValue(context, 'URL', _url),
                  theme: theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Status row
          Row(
            children: [
              if (_statusCode != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacityCompat(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withOpacityCompat(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacityCompat(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$_statusCode ${_getStatusText(_statusCode!)}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_durationMs != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.separatorColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: theme.secondaryTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_durationMs}ms',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    return _SectionCard(
      title: 'General',
      icon: Icons.info_outline_rounded,
      theme: theme,
      initiallyExpanded: false,
      onCopy: () => _copySection(context, 'General', {
        'Timestamp': entry.timestamp.toLocal().toIso8601String(),
        'Duration': _durationMs != null ? '${_durationMs}ms' : 'N/A',
        'Category': entry.category,
      }),
      child: Column(
        children: [
          _KeyValueRow(
            label: 'Timestamp',
            value: DateFormat('MMM dd, yyyy HH:mm:ss.SSS')
                .format(entry.timestamp.toLocal()),
            theme: theme,
            onCopy: () => _copyValue(
              context,
              'Timestamp',
              entry.timestamp.toLocal().toIso8601String(),
            ),
          ),
          if (_durationMs != null)
            _KeyValueRow(
              label: 'Duration',
              value: '${_durationMs}ms',
              theme: theme,
              onCopy: () => _copyValue(context, 'Duration', '${_durationMs}ms'),
            ),
          _KeyValueRow(
            label: 'Category',
            value: entry.category,
            theme: theme,
            onCopy: () => _copyValue(context, 'Category', entry.category),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSection(BuildContext context) {
    final hasHeaders = _ctx['requestHeaders'] != null;
    final hasBody = _ctx['requestBody'] != null;

    return _SectionCard(
      title: 'Request',
      icon: Icons.upload_rounded,
      theme: theme,
      onCopy: (hasHeaders || hasBody)
          ? () => _copySection(context, 'Request', {
                if (hasHeaders) 'headers': _ctx['requestHeaders'],
                if (hasBody) 'body': _ctx['requestBody'],
              })
          : null,
      child: (!hasHeaders && !hasBody)
          ? _EmptyState(text: 'No request data', theme: theme)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasHeaders)
                  _DataBlock(
                    title: 'Headers',
                    data: _ctx['requestHeaders'],
                    theme: theme,
                    onCopy: () => _copyValue(
                      context,
                      'Request Headers',
                      _ctx['requestHeaders'],
                    ),
                  ),
                if (hasHeaders && hasBody) const SizedBox(height: 14),
                if (hasBody)
                  _DataBlock(
                    title: 'Body',
                    data: _ctx['requestBody'],
                    theme: theme,
                    onCopy: () => _copyValue(
                      context,
                      'Request Body',
                      _ctx['requestBody'],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildResponseSection(BuildContext context) {
    final hasHeaders = _ctx['responseHeaders'] != null;
    final hasBody = _ctx['responseBody'] != null;
    final hasError = _ctx['error'] != null;

    return _SectionCard(
      title: 'Response',
      icon: Icons.download_rounded,
      theme: theme,
      onCopy: (hasHeaders || hasBody || hasError)
          ? () => _copySection(context, 'Response', {
                if (hasHeaders) 'headers': _ctx['responseHeaders'],
                if (hasBody) 'body': _ctx['responseBody'],
                if (hasError) 'error': _ctx['error'],
              })
          : null,
      child: (!hasHeaders && !hasBody && !hasError)
          ? _EmptyState(text: 'No response data', theme: theme)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError) ...[
                  _ErrorBanner(error: _ctx['error'].toString(), theme: theme),
                  const SizedBox(height: 14),
                ],
                if (hasHeaders)
                  _DataBlock(
                    title: 'Headers',
                    data: _ctx['responseHeaders'],
                    theme: theme,
                    onCopy: () => _copyValue(
                      context,
                      'Response Headers',
                      _ctx['responseHeaders'],
                    ),
                  ),
                if (hasHeaders && hasBody) const SizedBox(height: 14),
                if (hasBody)
                  _DataBlock(
                    title: 'Body',
                    data: _ctx['responseBody'],
                    theme: theme,
                    onCopy: () => _copyValue(
                      context,
                      'Response Body',
                      _ctx['responseBody'],
                    ),
                  ),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // COPY FUNCTIONS
  // ──────────────────────────────────────────────────────────────────────────

  void _copyAll(BuildContext context) {
    final json = const JsonEncoder.withIndent('  ').convert(entry.toJson());
    Clipboard.setData(ClipboardData(text: json));
    HapticFeedback.mediumImpact();
    _showToast(context, 'All data copied');
  }

  void _copyCurl(BuildContext context) {
    final curl = _generateCurl();
    Clipboard.setData(ClipboardData(text: curl));
    HapticFeedback.mediumImpact();
    _showToast(context, 'cURL copied');
  }

  void _copySection(BuildContext context, String name, dynamic data) {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: json));
    HapticFeedback.lightImpact();
    _showToast(context, '$name copied');
  }

  void _copyValue(BuildContext context, String name, dynamic value) {
    final text = value is String ? value : jsonEncode(value);
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _showToast(context, '$name copied');
  }

  String _generateCurl() {
    final buffer = StringBuffer('curl');
    if (_method != 'GET') buffer.write(' -X $_method');

    final headers = _ctx['requestHeaders'] as Map<String, dynamic>?;
    if (headers != null) {
      for (final e in headers.entries) {
        buffer.write(" -H '${e.key}: ${e.value}'");
      }
    }

    final body = _ctx['requestBody'];
    if (body != null) {
      final jsonBody = jsonEncode(body).replaceAll("'", "'\\''");
      buffer.write(" -d '$jsonBody'");
    }

    buffer.write(" '$_url'");
    return buffer.toString();
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: const Color(0xFF30D158),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF30D158);
      case 'POST':
        return const Color(0xFF007AFF);
      case 'PUT':
        return const Color(0xFFFF9500);
      case 'PATCH':
        return const Color(0xFFAF52DE);
      case 'DELETE':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return const Color(0xFF8E8E93);
    if (statusCode >= 200 && statusCode < 300) return const Color(0xFF30D158);
    if (statusCode >= 300 && statusCode < 400) return const Color(0xFFFF9500);
    if (statusCode >= 400 && statusCode < 500) return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  String _getStatusText(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Server Error';
      default:
        return '';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final LogViewerTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.accentColor.withOpacityCompat(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.accentColor.withOpacityCompat(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyIconButton extends StatelessWidget {
  const _CopyIconButton({required this.onTap, required this.theme});

  final VoidCallback onTap;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.copy_rounded,
            color: theme.secondaryTextColor,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.theme,
    required this.child,
    this.onCopy,
    this.initiallyExpanded = true,
  });

  final String title;
  final IconData icon;
  final LogViewerTheme theme;
  final Widget child;
  final VoidCallback? onCopy;
  final bool initiallyExpanded;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: _isExpanded ? Radius.zero : const Radius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.theme.accentColor.withOpacityCompat(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.theme.accentColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onCopy != null)
                      _CopyIconButton(
                        onTap: widget.onCopy!,
                        theme: widget.theme,
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: widget.theme.secondaryTextColor,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          if (_isExpanded) ...[
            Divider(height: 1, color: widget.theme.separatorColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.onCopy,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final LogViewerTheme theme;
  final VoidCallback onCopy;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 85,
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 13,
                  ),
                ),
              ),
              _CopyIconButton(onTap: onCopy, theme: theme),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: theme.separatorColor),
      ],
    );
  }
}

class _DataBlock extends StatelessWidget {
  const _DataBlock({
    required this.title,
    required this.data,
    required this.theme,
    required this.onCopy,
  });

  final String title;
  final dynamic data;
  final LogViewerTheme theme;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: theme.accentColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.separatorColor),
          ),
          child: _JsonTreeView(data: data, theme: theme),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text, required this.theme});

  final String text;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: theme.secondaryTextColor.withOpacityCompat(0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.theme});

  final String error;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacityCompat(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF3B30).withOpacityCompat(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacityCompat(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFF3B30),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonTreeView extends StatelessWidget {
  const _JsonTreeView({required this.data, required this.theme});

  final dynamic data;
  final LogViewerTheme theme;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Text(
        'null',
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      );
    }

    if (data is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in (data as Map).entries)
            _JsonNode(
              keyName: entry.key.toString(),
              value: entry.value,
              theme: theme,
            ),
        ],
      );
    }

    if (data is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < (data as List).length; i++)
            _JsonNode(keyName: '[$i]', value: data[i], theme: theme),
        ],
      );
    }

    return Text(
      data.toString(),
      style: TextStyle(
        color: theme.textColor,
        fontFamily: 'monospace',
        fontSize: 12,
      ),
    );
  }
}

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    required this.keyName,
    required this.value,
    required this.theme,
    this.depth = 0,
  });

  final String keyName;
  final dynamic value;
  final LogViewerTheme theme;
  final int depth;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  bool _isExpanded = true;

  bool get _isExpandable =>
      widget.value is Map || (widget.value is List && widget.value.isNotEmpty);

  Color get _valueColor {
    final v = widget.value;
    if (v == null) return widget.theme.secondaryTextColor;
    if (v is String) return const Color(0xFF30D158);
    if (v is num) return const Color(0xFF64D2FF);
    if (v is bool) return const Color(0xFFFF9F0A);
    return widget.theme.textColor;
  }

  String get _typeIndicator {
    final v = widget.value;
    if (v is Map) return '{${v.length}}';
    if (v is List) return '[${v.length}]';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isExpandable
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _isExpanded = !_isExpanded);
                }
              : null,
          child: Padding(
            padding: EdgeInsets.only(left: indent, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isExpandable)
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: widget.theme.secondaryTextColor,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 2),
                Text(
                  widget.keyName,
                  style: TextStyle(
                    color: widget.theme.accentColor,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ': ',
                  style: TextStyle(
                    color: widget.theme.secondaryTextColor,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                if (_isExpandable)
                  Text(
                    _typeIndicator,
                    style: TextStyle(
                      color: widget.theme.secondaryTextColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      _formatValue(widget.value),
                      style: TextStyle(
                        color: _valueColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isExpandable && _isExpanded) _buildChildren(),
      ],
    );
  }

  Widget _buildChildren() {
    final v = widget.value;

    if (v is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in v.entries)
            _JsonNode(
              keyName: e.key.toString(),
              value: e.value,
              theme: widget.theme,
              depth: widget.depth + 1,
            ),
        ],
      );
    }

    if (v is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < v.length; i++)
            _JsonNode(
              keyName: '[$i]',
              value: v[i],
              theme: widget.theme,
              depth: widget.depth + 1,
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    return value.toString();
  }
}
