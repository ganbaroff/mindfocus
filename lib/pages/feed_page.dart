import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Feed page — OSINT + bot notifications with score filtering.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _poller;
  String _filter = 'all'; // all, high, ai, pm, biz

  static const _feedUrl = 'http://localhost:8585/feed';

  @override
  void initState() {
    super.initState();
    _fetchFeed();
    _poller = Timer.periodic(const Duration(seconds: 10), (_) => _fetchFeed());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    try {
      final resp = await http.get(Uri.parse(_feedUrl));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          _items = data.cast<Map<String, dynamic>>().reversed.toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Bot offline — start Docker container';
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'high':
        return _items.where((i) => (i['score'] ?? 0) >= 8).toList();
      case 'ai':
        return _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('ai') || s.contains('neural') || s == 'ai';
        }).toList();
      case 'pm':
        return _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('pm') || s.contains('agile');
        }).toList();
      case 'biz':
        return _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('startup') ||
              s.contains('venture') ||
              s.contains('invest') ||
              s.contains('temno');
        }).toList();
      default:
        return _items;
    }
  }

  IconData _sourceIcon(String source) {
    final s = source.toLowerCase();
    if (s.contains('osint')) return Icons.radar;
    if (s == 'telegram') return Icons.telegram;
    if (s == 'ai') return Icons.smart_toy;
    if (s == 'digest') return Icons.newspaper;
    if (s == 'rca') return Icons.analytics;
    if (s == 'system') return Icons.settings;
    return Icons.notifications;
  }

  String _formatSource(String source) {
    if (source.startsWith('osint:')) {
      return '@${source.substring(6)}';
    }
    return source.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Container(
      decoration: AppTheme.pageGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Feed'),
              if (_items.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_items.length}',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _fetchFeed,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', 'all'),
                  _filterChip('🔥 Hot', 'high'),
                  _filterChip('🤖 AI', 'ai'),
                  _filterChip('📋 PM', 'pm'),
                  _filterChip('💼 Biz', 'biz'),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 48,
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text(_error!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed: _fetchFeed,
                                  child: const Text('Retry')),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                  _filter == 'all'
                                      ? 'No feed items yet'
                                      : 'No items match this filter',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary)),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchFeed,
                              color: AppTheme.accent,
                              child: ListView.builder(
                                itemCount: filtered.length,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemBuilder: (ctx, i) =>
                                    _buildFeedCard(filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withOpacity(0.25)
                : AppTheme.surfaceLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> item) {
    final score = item['score'] as int? ?? 5;
    final source = item['source'] as String? ?? 'system';
    final text = item['text'] as String? ?? '';
    final timeStr = item['time'] as String? ?? '';

    String displayTime = '';
    try {
      final dt = DateTime.parse(timeStr);
      displayTime =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (dCtx) => Dialog(
            backgroundColor: AppTheme.surfaceLight,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_sourceIcon(source),
                        size: 18, color: AppTheme.scoreColor(score)),
                    const SizedBox(width: 8),
                    Text(_formatSource(source),
                        style: TextStyle(
                            color: AppTheme.scoreColor(score),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const Spacer(),
                    AppTheme.scoreBadge(score),
                  ]),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      child: SelectableText(text,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                        onPressed: () => Navigator.of(dCtx).pop(),
                        child: const Text('Close')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.scoreColor(score).withOpacity(0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.scoreColor(score).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_sourceIcon(source),
                  color: AppTheme.scoreColor(score), size: 18),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.length > 120 ? '${text.substring(0, 120)}...' : text,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(_formatSource(source),
                        style: TextStyle(
                            color: AppTheme.scoreColor(score),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(displayTime,
                        style: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.6),
                            fontSize: 10)),
                    const Spacer(),
                    AppTheme.scoreBadge(score),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
