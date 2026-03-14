import 'package:flutter/material.dart';
import '../services/explanation_service.dart';

class ExplanationScreen extends StatefulWidget {
  final String objectName;
  const ExplanationScreen({super.key, required this.objectName});

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen> {
  String _level = 'simple';
  String? _explanation;
  bool _loading = false;
  String? _error;

  static const _levels = [
    _Level('simple',   'Simple',   Icons.child_care_rounded,  'Easy words, for kids',     Color(0xFF27AE60)),
    _Level('medium',   'Medium',   Icons.school_rounded,       'High-school level',         Color(0xFFF39C12)),
    _Level('advanced', 'Advanced', Icons.biotech_rounded,      'Technical & detailed',     Color(0xFFE74C3C)),
  ];

  _Level get _current => _levels.firstWhere((l) => l.id == _level);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; _explanation = null; });
    try {
      final text = await ExplanationService.explain(
          widget.objectName.toLowerCase(), _level);
      if (mounted) setState(() => _explanation = text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top bar
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
              Expanded(
                child: Text(widget.objectName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // Object hero card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF162032)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D9CDB).withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.crop_free_rounded,
                      color: Color(0xFF2D9CDB), size: 28),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.objectName,
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Detected on-device • ML Kit',
                      style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 12)),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Level selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Choose explanation level',
                  style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: _levels.asMap().entries.map((e) {
                final lv = e.value;
                final isLast = e.key == _levels.length - 1;
                final selected = _level == lv.id;
                return Expanded(child: GestureDetector(
                  onTap: () {
                    if (_level == lv.id) return;
                    setState(() => _level = lv.id);
                    _fetch();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: isLast ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected ? lv.color.withOpacity(0.15) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? lv.color.withOpacity(0.6) : const Color(0xFF30363D),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Icon(lv.icon, color: selected ? lv.color : Colors.white38, size: 22),
                      const SizedBox(height: 5),
                      Text(lv.label,
                          style: TextStyle(
                            color: selected ? lv.color : Colors.white54,
                            fontSize: 12, fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                ));
              }).toList()),
            ]),
          ),

          const SizedBox(height: 20),

          // Explanation card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: _buildBody(),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    final lv = _current;

    if (_loading) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: lv.color, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Generating ${lv.label.toLowerCase()} explanation…',
            style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 14)),
      ]);
    }

    if (_error != null) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 48),
        const SizedBox(height: 12),
        const Text('Couldn\'t load explanation',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center, maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D9CDB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]);
    }

    if (_explanation == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(lv.icon, color: lv.color, size: 16),
        const SizedBox(width: 6),
        Text('${lv.label} Explanation',
            style: TextStyle(color: lv.color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 2),
      Text(lv.description,
          style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
      const SizedBox(height: 14),
      Divider(color: lv.color.withOpacity(0.2)),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          child: Text(_explanation!,
              style: const TextStyle(color: Color(0xFFCDD9E5),
                  fontSize: 15, height: 1.7)),
        ),
      ),
    ]);
  }
}

class _Level {
  final String id, label, description;
  final IconData icon;
  final Color color;
  const _Level(this.id, this.label, this.icon, this.description, this.color);
}
