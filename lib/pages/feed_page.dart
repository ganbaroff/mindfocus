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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const _cloudUrl =
      'https://mindfocus-827100239570.europe-west1.run.app/feed';
  final String _feedUrl = _cloudUrl;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
    _poller = Timer.periodic(const Duration(seconds: 10), (_) => _fetchFeed());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    try {
      final resp = await http
          .get(Uri.parse(_feedUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          _items = data.cast<Map<String, dynamic>>().reversed.toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (_items.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Connecting to Cloud... Retry in 3s';
        });
        // Auto-retry once after cold-start delay
        Future.delayed(
            const Duration(seconds: 3), () => mounted ? _fetchFeed() : null);
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> res;
    switch (_filter) {
      case 'high':
        res = _items.where((i) => (i['score'] ?? 0) >= 8).toList();
        break;
      case 'ai':
        res = _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('ai') || s.contains('neural') || s == 'ai';
        }).toList();
        break;
      case 'pm':
        res = _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('pm') || s.contains('agile');
        }).toList();
        break;
      case 'biz':
        res = _items.where((i) {
          final s = (i['source'] ?? '').toString().toLowerCase();
          return s.contains('startup') ||
              s.contains('venture') ||
              s.contains('invest') ||
              s.contains('temno');
        }).toList();
        break;
      default:
        res = _items;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      res = res.where((i) {
        final title = (i['title'] ?? '').toString().toLowerCase();
        final text = (i['text'] ?? '').toString().toLowerCase();
        final summary = (i['summary'] ?? '').toString().toLowerCase();
        return title.contains(q) || text.contains(q) || summary.contains(q);
      }).toList();
    }
    return res;
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
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search feed...',
                  hintStyle:
                      TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search,
                      color: AppTheme.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppTheme.textSecondary, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceLight.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
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
    final summary = item['summary'] as String? ?? '';
    final timeStr = item['time'] as String? ?? '';

    String displayTime = '';
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        displayTime = '${diff.inMinutes}м назад';
      } else if (diff.inHours < 24) {
        displayTime = '${diff.inHours}ч назад';
      } else {
        displayTime =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    final hasSummary = summary.isNotEmpty;

    return GestureDetector(
      onTap: () => _showDetail(item, source, text, summary, score),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card.withOpacity(score >= 8 ? 0.5 : 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                AppTheme.scoreColor(score).withOpacity(score >= 8 ? 0.3 : 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: source + score + time
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.scoreColor(score).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_sourceIcon(source),
                    color: AppTheme.scoreColor(score), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_formatSource(source),
                    style: TextStyle(
                        color: AppTheme.scoreColor(score),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              Text(displayTime,
                  style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      fontSize: 10)),
              const SizedBox(width: 8),
              AppTheme.scoreBadge(score),
            ]),

            const SizedBox(height: 10),

            // AI Summary (if available) — prominent glass card
            if (hasSummary) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome,
                          size: 12, color: AppTheme.accent.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text('AI Summary',
                          style: TextStyle(
                              color: AppTheme.accent.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Text(summary,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Post text (bigger context window)
            Text(
              text.length > 250 ? '${text.substring(0, 250)}...' : text,
              style: TextStyle(
                color: hasSummary
                    ? AppTheme.textSecondary.withOpacity(0.7)
                    : AppTheme.textPrimary,
                fontSize: hasSummary ? 12 : 14,
                height: 1.4,
              ),
              maxLines: hasSummary ? 3 : 6,
              overflow: TextOverflow.ellipsis,
            ),

            // "Read more" hint
            if (text.length > 250)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Tap to read more →',
                    style: TextStyle(
                        color: AppTheme.accent.withOpacity(0.6),
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item, String source, String text,
      String summary, int score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Icon(_sourceIcon(source),
                      size: 20, color: AppTheme.scoreColor(score)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_formatSource(source),
                        style: TextStyle(
                            color: AppTheme.scoreColor(score),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                  AppTheme.scoreBadge(score),
                ]),
              ),
              const Divider(color: AppTheme.divider, height: 24),
              // Body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (summary.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.auto_awesome,
                                  size: 14, color: AppTheme.accent),
                              const SizedBox(width: 6),
                              const Text('AI Summary',
                                  style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 8),
                            Text(summary,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    height: 1.6)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Original Post',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                    ],
                    SelectableText(text,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            height: 1.6)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
