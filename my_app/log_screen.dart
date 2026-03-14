import 'package:flutter/material.dart';
import '../services/log_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late Future<List<DetectionLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = LogService.getLogs();
  }

  void _reload() => setState(() => _logsFuture = LogService.getLogs());

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Logs',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete all detection logs?',
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
      await LogService.clearLogs();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────────
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
              const Expanded(
                child: Text('Detection Logs',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ),
              // Clear button
              GestureDetector(
                onTap: _clearAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    Text('Clear',
                        style: TextStyle(
                            color: Color(0xFFE74C3C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          const Divider(color: Color(0xFF30363D), height: 1),

          // ── Log list ──────────────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<DetectionLogEntry>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2D9CDB)));
                }

                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              color: Colors.white24, size: 64),
                          const SizedBox(height: 12),
                          const Text('No detection logs yet.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 14)),
                          const SizedBox(height: 6),
                          const Text(
                              'Capture images to start logging detections.',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 12)),
                        ]),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _LogTile(entry: logs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Single log tile ───────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final DetectionLogEntry entry;
  const _LogTile({required this.entry});

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final d = dt.toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year}  $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF2D9CDB).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.crop_free_rounded,
              color: Color(0xFF2D9CDB), size: 18),
        ),
        const SizedBox(width: 12),
        // Text
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              entry.objectName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              _formatDate(entry.timestamp),
              style: const TextStyle(
                  color: Color(0xFF8B9CB6), fontSize: 11),
            ),
          ]),
        ),
      ]),
    );
  }
}
