import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/log_service.dart';
import 'auth_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Future<List<AppUser>> _usersFuture;
  late Future<List<DetectionLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _reload() => setState(() {
    _usersFuture = AuthService.allUsers();
    _logsFuture  = LogService.getAllLogs();
  });

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot delete an admin account.'),
        backgroundColor: Color(0xFFE74C3C),
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${user.username}?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This removes their profile and all detection logs.',
            style: TextStyle(color: Color(0xFF8B9CB6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B9CB6)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFE74C3C)))),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.deleteUser(user.uid);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Admin Dashboard', style: TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Object Learner — admin view',
                    style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 12)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9B59B6).withOpacity(0.3)),
                ),
                child: const Text('Admin', style: TextStyle(color: Color(0xFF9B59B6),
                    fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: Color(0xFFE74C3C), size: 18),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Stats
          FutureBuilder<List<DetectionLogEntry>>(
            future: _logsFuture,
            builder: (_, logSnap) => FutureBuilder<List<AppUser>>(
              future: _usersFuture,
              builder: (_, userSnap) {
                final userCount = userSnap.data?.length ?? 0;
                final logCount  = logSnap.data?.length ?? 0;
                final unique    = logSnap.data
                    ?.map((e) => e.objectName.toLowerCase()).toSet().length ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _StatCard('$userCount', 'Users', const Color(0xFF2D9CDB)),
                    const SizedBox(width: 10),
                    _StatCard('$logCount', 'Total Detections', const Color(0xFF27AE60)),
                    const SizedBox(width: 10),
                    _StatCard('$unique', 'Unique Objects', const Color(0xFFF39C12)),
                  ]),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(color: const Color(0xFF2D9CDB),
                    borderRadius: BorderRadius.circular(11)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF8B9CB6),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [Tab(text: 'Users'), Tab(text: 'All Logs')],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_usersTab(), _logsTab()],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _usersTab() => FutureBuilder<List<AppUser>>(
    future: _usersFuture,
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF2D9CDB)));
      }
      final users = snap.data ?? [];
      if (users.isEmpty) return const Center(
          child: Text('No users yet.', style: TextStyle(color: Colors.white38)));
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) =>
            _UserTile(user: users[i], onDelete: () => _deleteUser(users[i])),
      );
    },
  );

  Widget _logsTab() => FutureBuilder<List<DetectionLogEntry>>(
    future: _logsFuture,
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF2D9CDB)));
      }
      final logs = snap.data ?? [];
      if (logs.isEmpty) return const Center(
          child: Text('No detection logs yet.',
              style: TextStyle(color: Colors.white38)));
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _AdminLogTile(entry: logs[i]),
      );
    },
  );
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 10)),
      ]),
    ),
  );
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onDelete;
  const _UserTile({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';
    final roleColor = isAdmin ? const Color(0xFF9B59B6) : const Color(0xFF2D9CDB);
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = user.createdAt.toLocal();
    final joined = '${months[d.month-1]} ${d.day}, ${d.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: roleColor.withOpacity(0.15),
              shape: BoxShape.circle),
          child: Center(child: Text(user.username[0].toUpperCase(),
              style: TextStyle(color: roleColor, fontSize: 16,
                  fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(user.username, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(user.role, style: TextStyle(color: roleColor,
                  fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(user.email, style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
          Text('Joined $joined',
              style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
        ])),
        if (!isAdmin)
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE74C3C), size: 16),
            ),
          ),
      ]),
    );
  }
}

class _AdminLogTile extends StatelessWidget {
  final DetectionLogEntry entry;
  const _AdminLogTile({required this.entry});

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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF27AE60).withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.crop_free_rounded,
            color: Color(0xFF27AE60), size: 15),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.objectName, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.person_outline_rounded, color: Color(0xFF8B9CB6), size: 11),
          const SizedBox(width: 3),
          Text(entry.username, style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
          const SizedBox(width: 8),
          Text(_fmt(entry.timestamp),
              style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
        ]),
      ])),
    ]),
  );
}
