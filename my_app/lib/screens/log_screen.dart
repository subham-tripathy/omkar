import 'package:flutter/material.dart';
import '../services/log_service.dart';

class LogScreen extends StatefulWidget {
  final String uid;
  const LogScreen({super.key, required this.uid});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late Future<List<DetectionLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _logsFuture = LogService.getLogsForUser(widget.uid));

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Logs',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Delete all detection logs?',
            style: TextStyle(color: Color(0xFF8B9CB6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8B9CB6)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFE74C3C)))),
        ],
      ),
    );
    if (confirm == true) {
      await LogService.clearLogsForUser(widget.uid);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Text('Detection Logs',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: _clearAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE74C3C).withOpacity(0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE74C3C), size: 14),
                    SizedBox(width: 4),
                    Text('Clear', style: TextStyle(
                        color: Color(0xFFE74C3C), fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          Expanded(
            child: FutureBuilder<List<DetectionLogEntry>>(
              future: _logsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: Color(0xFF2D9CDB)));
                }
                final logs = snap.data ?? [];
                if (logs.isEmpty) {
                  return const Center(child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.receipt_long_outlined,
                        color: Colors.white24, size: 52),
                    SizedBox(height: 10),
                    Text('No logs yet.',
                        style: TextStyle(color: Colors.white38, fontSize: 14)),
                  ]));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogTile(entry: logs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final DetectionLogEntry entry;
  const _LogTile({required this.entry});

  String _fmt(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = dt.toLocal();
    return '${months[d.month - 1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')}:'
        '${d.second.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2D9CDB).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.crop_free_rounded,
            color: Color(0xFF2D9CDB), size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(entry.objectName, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(_fmt(entry.timestamp),
            style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
      ])),
    ]),
  );
}
