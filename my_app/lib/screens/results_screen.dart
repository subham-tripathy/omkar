import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import 'explanation_screen.dart';
import 'log_screen.dart';

class ResultsScreen extends StatelessWidget {
  final DetectionResult detectionResult;
  final Uint8List capturedImageBytes;

  const ResultsScreen({
    super.key,
    required this.detectionResult,
    required this.capturedImageBytes,
  });

  // ── Deduplicate: keep highest-confidence entry per label ─────────────────
  List<MapEntry<String, double>> get _uniqueObjects {
    final best = <String, double>{};
    for (final obj in detectionResult.objects) {
      // Normalise to lowercase key for dedup, display label stays as-is
      final key = obj.label.toLowerCase().trim();
      if ((best[key] ?? 0) < obj.confidence) best[key] = obj.confidence;
    }
    // Re-map keys back to the original cased label from the first object
    final keyToLabel = <String, String>{};
    for (final obj in detectionResult.objects) {
      final key = obj.label.toLowerCase().trim();
      keyToLabel.putIfAbsent(key, () => _fmt(obj.label));
    }
    return best.entries
        .map((e) => MapEntry(keyToLabel[e.key]!, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  int _count(String fmtLabel) => detectionResult.objects
      .where((o) => _fmt(o.label).toLowerCase() == fmtLabel.toLowerCase())
      .length;

  String _fmt(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  Color _confColor(double c) =>
      c >= 0.75 ? const Color(0xFF27AE60) :
      c >= 0.50 ? const Color(0xFFF39C12) :
                  const Color(0xFFE74C3C);

  @override
  Widget build(BuildContext context) {
    final items      = _uniqueObjects;
    final hasObjects = items.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top bar ────────────────────────────────────────────────────
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
                child: Text('Detection Results',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LogScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2D9CDB).withOpacity(0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_rounded, color: Color(0xFF2D9CDB), size: 14),
                    SizedBox(width: 4),
                    Text('Logs', style: TextStyle(color: Color(0xFF2D9CDB),
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Captured image + bounding boxes ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: detectionResult.imageWidth / detectionResult.imageHeight,
                child: LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(children: [
                    // Photo
                    Image.memory(capturedImageBytes,
                        fit: BoxFit.cover,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight),
                    // Bounding boxes
                    ...detectionResult.objects.map((obj) => Positioned(
                      left:   obj.x * constraints.maxWidth,
                      top:    obj.y * constraints.maxHeight,
                      width:  obj.width  * constraints.maxWidth,
                      height: obj.height * constraints.maxHeight,
                      child: _BoundingBox(
                        label:      _fmt(obj.label),
                        confidence: obj.confidence,
                        color:      _confColor(obj.confidence),
                      ),
                    )),
                  ]);
                }),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Stats strip ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Chip(icon: Icons.category_outlined,
                    label: '${detectionResult.objects.length} detection${detectionResult.objects.length != 1 ? 's' : ''}',
                    color: const Color(0xFF2D9CDB)),
                const SizedBox(width: 8),
                _Chip(icon: Icons.layers_outlined,
                    label: '${items.length} unique',
                    color: const Color(0xFF27AE60)),
                const SizedBox(width: 8),
                const _Chip(icon: Icons.auto_awesome_rounded,
                    label: 'Groq Vision AI',
                    color: Color(0xFF9B59B6)),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              hasObjects
                  ? 'Tap any object to learn about it'
                  : 'No objects detected',
              style: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 13),
            ),
          ),

          const SizedBox(height: 8),

          // ── Object list ────────────────────────────────────────────────
          Flexible(
            child: hasObjects
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final label = items[i].key;
                      final conf  = items[i].value;
                      return _ObjectTile(
                        label:      label,
                        count:      _count(label),
                        confidence: conf,
                        confColor:  _confColor(conf),
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => ExplanationScreen(objectName: label),
                        )),
                      );
                    },
                  )
                : Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.search_off_rounded,
                          color: Colors.white24, size: 64),
                      const SizedBox(height: 12),
                      const Text(
                        'No objects found.\nTry better lighting or get closer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D9CDB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
      ),
    );
  }
}

// ── Bounding box overlay ──────────────────────────────────────────────────────

class _BoundingBox extends StatefulWidget {
  final String label;
  final double confidence;
  final Color color;
  const _BoundingBox(
      {required this.label, required this.confidence, required this.color});

  @override
  State<_BoundingBox> createState() => _BoundingBoxState();
}

class _BoundingBoxState extends State<_BoundingBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Full box border (semi-transparent fill + solid border)
            Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08),
                border: Border.all(color: widget.color, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Corner accent brackets painted on top
            Positioned.fill(
              child: CustomPaint(
                painter: _CornerPainter(color: widget.color),
              ),
            ),
            // Label badge
            Positioned(
              top: -26,
              left: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: widget.color.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(widget.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws bright corner-bracket accents at each corner of the bounding box.
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final len = math.min(size.width, size.height) * 0.22;
    final r = 4.0;

    // Top-left
    canvas.drawLine(Offset(0, r + len), Offset(0, r), paint);
    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), paint);

    // Top-right
    canvas.drawLine(
        Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(
        Offset(size.width, r), Offset(size.width, r + len), paint);

    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height - r - len), Offset(0, size.height - r), paint);
    canvas.drawLine(
        Offset(r, size.height), Offset(r + len, size.height), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - r - len, size.height),
        Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r - len),
        Offset(size.width, size.height - r), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}


// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ObjectTile extends StatelessWidget {
  final String label;
  final int count;
  final double confidence;
  final Color confColor;
  final VoidCallback onTap;

  const _ObjectTile({
    required this.label, required this.count,
    required this.confidence, required this.confColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.crop_free_rounded,
              color: Color(0xFF2D9CDB), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Flexible(child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w600))),
            if (count > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D9CDB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('×$count',
                    style: const TextStyle(color: Color(0xFF2D9CDB),
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: confColor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${(confidence * 100).toStringAsFixed(0)}% confidence',
                style: TextStyle(color: confColor, fontSize: 12)),
          ]),
        ])),
        const Icon(Icons.chevron_right_rounded,
            color: Color(0xFF8B9CB6), size: 22),
      ]),
    ),
  );
}
