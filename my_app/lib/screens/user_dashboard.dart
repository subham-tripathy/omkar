import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/log_service.dart';
import 'auth_screen.dart';
import 'camera_screen.dart';

class UserDashboard extends StatefulWidget {
  final AppUser user;
  const UserDashboard({super.key, required this.user});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  late Future<List<DetectionLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _logsFuture = LogService.getLogsForUser(widget.user.uid));

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _clearLogs() async {
    await LogService.clearLogsForUser(widget.user.uid);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hi, ${widget.user.username} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const Text('Your detection dashboard',
                    style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 12)),
              ]),
              const Spacer(),
              _IconBtn(icon: Icons.logout_rounded,
                  color: const Color(0xFFE74C3C), onTap: _logout),
            ]),
          ),

          const SizedBox(height: 20),

          // Scan button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CameraScreen(currentUser: widget.user)));
                _reload();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF162032)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF2D9CDB).withOpacity(0.4)),
                ),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D9CDB).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Color(0xFF2D9CDB), size: 26),
                  ),
                  const SizedBox(width: 16),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Scan an Object',
                        style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Tap to open camera & detect',
                        style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF2D9CDB), size: 24),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Detection History',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _clearLogs,
                child: const Text('Clear all',
                    style: TextStyle(color: Color(0xFFE74C3C), fontSize: 12)),
              ),
            ]),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: FutureBuilder<List<DetectionLogEntry>>(
              future: _logsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: Color(0xFF2D9CDB)));
                }
                final logs = snap.data ?? [];
                final uniqueObjects =
                    logs.map((e) => e.objectName).toSet().length;

                return Column(children: [
                  // Stats
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(children: [
                      _StatCard(value: '${logs.length}',
                          label: 'Total Detections',
                          color: const Color(0xFF2D9CDB)),
                      const SizedBox(width: 12),
                      _StatCard(value: '$uniqueObjects',
                          label: 'Unique Objects',
                          color: const Color(0xFF27AE60)),
                    ]),
                  ),

                  Expanded(
                    child: logs.isEmpty
                        ? const Center(child: Column(mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(Icons.search_off_rounded,
                              color: Colors.white24, size: 52),
                          SizedBox(height: 10),
                          Text('No detections yet.\nTap "Scan" to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13)),
                        ]))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _LogTile(entry: logs[i]),
                          ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 24,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
      ]),
    ),
  );
}

class _LogTile extends StatelessWidget {
  final DetectionLogEntry entry;
  const _LogTile({required this.entry});

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month-1]} ${d.day}, ${d.year}  '
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}
