import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/brain_dump_provider.dart';
import '../theme/app_theme.dart';

class BrainDumpPage extends StatelessWidget {
  const BrainDumpPage({super.key});

  String _detectTag(String text) {
    if (text.startsWith('#task')) return '#task';
    if (text.startsWith('#linkedin')) return '#linkedin';
    if (text.startsWith('#azlife')) return '#azlife';
    return '';
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case '#task':
        return AppTheme.warning;
      case '#linkedin':
        return const Color(0xFF0077B5);
      case '#azlife':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<BrainDumpProvider>(context);
    return Container(
      decoration: AppTheme.pageGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Brain Dump'),
          actions: [
            if (p.isGenerating)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent)),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context, p),
          child: const Icon(Icons.add),
        ),
        body: p.thoughts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology_outlined,
                        size: 64, color: AppTheme.primary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text('Empty mind is a calm mind',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('Tap + to dump your thoughts',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: p.thoughts.length,
                itemBuilder: (ctx, i) {
                  final thought = p.thoughts[i];
                  final tag = _detectTag(thought);
                  return Dismissible(
                    key: Key('$i-$thought'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                    ),
                    onDismissed: (_) {
                      p.deleteThought(i);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thought deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => p.addThought(thought),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard(opacity: 0.15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tag.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _tagColor(tag).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _tagColor(tag).withOpacity(0.4)),
                              ),
                              child: Text(tag,
                                  style: TextStyle(
                                      color: _tagColor(tag),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          Text(
                            tag.isNotEmpty
                                ? thought.substring(tag.length).trim()
                                : thought,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _actionButton(
                                icon: Icons.auto_awesome,
                                color: AppTheme.accent,
                                onTap: p.isGenerating
                                    ? null
                                    : () =>
                                        _processThought(context, p, thought),
                              ),
                              const SizedBox(width: 8),
                              _actionButton(
                                icon: Icons.copy,
                                color: AppTheme.textSecondary,
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: thought));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showAddSheet(BuildContext context, BrainDumpProvider p) {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: "What's on your mind?  (#task, #linkedin)",
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (c.text.trim().isNotEmpty) {
                  p.addThought(c.text.trim());
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Thought'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _processThought(
      BuildContext context, BrainDumpProvider p, String thought) async {
    final result = await p.processThought(thought);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: AppTheme.accent, size: 20),
                SizedBox(width: 8),
                Text('AI Result',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: SelectableText(result,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result));
                      Navigator.of(dCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!')),
                      );
                    },
                    child: const Text('Copy',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dCtx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
