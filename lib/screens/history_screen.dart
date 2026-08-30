// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../theme/ceylon_spice.dart';
import '../utils/history_storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await HistoryStorage.load();
    setState(() { _history = data; _loading = false; });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CeylonSpice.coconutCream,
        title: Text('Clear History',
            style: TextStyle(color: CeylonSpice.text, fontWeight: FontWeight.w700)),
        content: Text('Delete all detection history?',
            style: TextStyle(color: CeylonSpice.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: CeylonSpice.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: CeylonSpice.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryStorage.clear();
      setState(() => _history = []);
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpice.coconutCream,
      body: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: CeylonSpice.surface,
              border: Border(bottom: BorderSide(color: CeylonSpice.saffron, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detection History',
                  style: TextStyle(
                    color: CeylonSpice.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_history.isNotEmpty)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: CeylonSpice.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: CeylonSpice.cinnamon))
                : _history.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: CeylonSpice.cinnamon,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _HistoryCard(
                            entry: _history[i],
                            formatTime: _formatTime,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final String Function(DateTime) formatTime;

  const _HistoryCard({required this.entry, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final isHate      = entry.isHateSpeech;
    final accentColor = isHate ? CeylonSpice.danger    : CeylonSpice.deepJungle;
    final bgColor     = isHate ? CeylonSpice.dangerLight : CeylonSpice.cleanBg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isHate ? '🔴' : '🟢', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                isHate ? 'HATE SPEECH' : 'SAFE',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                formatTime(entry.timestamp),
                style: TextStyle(color: CeylonSpice.textLight, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Text(
                entry.inputMode == 'voice' ? '🎤' : '⌨️',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: CeylonSpice.text, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Confidence: ${(entry.confidence * 100).round()}%',
                style: TextStyle(color: CeylonSpice.textMid, fontSize: 11),
              ),
              if (entry.harshWords.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  '⚠️ ${entry.harshWords.length} harsh word${entry.harshWords.length != 1 ? "s" : ""}',
                  style: TextStyle(color: CeylonSpice.cinnamon, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📋', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text('No detections yet.',
              style: TextStyle(color: CeylonSpice.textMid, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Analyze some text to see results here.',
              style: TextStyle(color: CeylonSpice.textLight, fontSize: 13)),
        ],
      ),
    );
  }
}
