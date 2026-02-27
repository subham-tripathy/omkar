import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../widgets/bounding_box_painter.dart';
import '../widgets/explanation_sheet.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  List<DetectedObject> _detectedObjects = [];
  bool _isDetecting = false;
  bool _isCameraReady = false;
  Timer? _detectionTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras found');
        return;
      }
      await _startCamera(_cameras.first);
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
        _startDetectionLoop();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to init camera: $e');
    }
  }

  void _startDetectionLoop() {
    // Run detection every 1.5 seconds to avoid hammering the backend
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_isDetecting && _controller!.value.isInitialized) {
        _runDetection();
      }
    });
  }

  Future<void> _runDetection() async {
    if (_isDetecting || _controller == null) return;
    _isDetecting = true;

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final result = await ApiService.detectObjects(bytes);
      if (mounted) {
        setState(() => _detectedObjects = result.objects);
      }
    } catch (e) {
      // Silently ignore detection errors (network hiccup etc.)
    } finally {
      _isDetecting = false;
    }
  }

  void _onTapDetection(TapDownDetails details, BoxConstraints constraints) {
    final tapX = details.localPosition.dx / constraints.maxWidth;
    final tapY = details.localPosition.dy / constraints.maxHeight;

    for (final obj in _detectedObjects) {
      if (obj.containsPoint(tapX, tapY)) {
        _showExplanation(obj);
        return;
      }
    }
  }

  void _showExplanation(DetectedObject obj) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExplanationSheet(detectedObject: obj),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _detectionTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_isCameraReady) _startDetectionLoop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!);
    }

    if (!_isCameraReady) {
      return const _LoadingView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Preview ──────────────────────────────────────────────────
          Positioned.fill(child: CameraPreview(_controller!)),

          // ── Bounding Boxes + Tap detection ─────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (d) => _onTapDetection(d, constraints),
                  child: CustomPaint(
                    painter: BoundingBoxPainter(
                      objects: _detectedObjects,
                      canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Top Bar ─────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              objectCount: _detectedObjects.length,
              isDetecting: _isDetecting,
              onBack: () => Navigator.pop(context),
            ),
          ),

          // ── Hint banner ─────────────────────────────────────────────────────
          if (_detectedObjects.isNotEmpty)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: _HintBanner(count: _detectedObjects.length),
            ),
        ],
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int objectCount;
  final bool isDetecting;
  final VoidCallback onBack;

  const _TopBar(
      {required this.objectCount,
      required this.isDetecting,
      required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: onBack,
          ),
          const Spacer(),
          // Detection status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDetecting
                  ? const Color(0xFF6C63FF).withOpacity(0.8)
                  : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDetecting)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3ECFCF),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  isDetecting ? 'Analyzing...' : '$objectCount object(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hint Banner ──────────────────────────────────────────────────────────────
class _HintBanner extends StatelessWidget {
  final int count;
  const _HintBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.touch_app_rounded,
              color: Color(0xFF3ECFCF), size: 18),
          const SizedBox(width: 8),
          Text(
            'Tap any highlighted object to learn about it',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.3, end: 0);
  }
}

// ─── Loading View ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(height: 20),
            Text('Starting camera...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
