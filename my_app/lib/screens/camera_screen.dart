import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../services/log_service.dart';
import '../models/detection_model.dart';
import 'results_screen.dart';
import 'log_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(back, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _captureAndDetect() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturing = true);
    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List imageBytes = await file.readAsBytes();
      if (!mounted) return;

      final DetectionResult result = await DetectionService.detect(imageBytes);
      if (!mounted) return;

      // ── Log every detected object name ──────────────────────────────────
      if (result.objects.isNotEmpty) {
        final names = result.objects
            .map((o) => o.label[0].toUpperCase() + o.label.substring(1).replaceAll('_', ' '))
            .toList();
        await LogService.logDetections(names);
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            detectionResult: result,
            capturedImageBytes: imageBytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview / state views
          if (_isInitialized && _controller != null)
            GestureDetector(
              onTap: _captureAndDetect,
              child: CameraPreview(_controller!),
            )
          else if (_errorMessage != null)
            _ErrorView(message: _errorMessage!, onRetry: () {
              setState(() { _errorMessage = null; _isInitialized = false; });
              _initCamera();
            })
          else
            const _LoadingView(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _TopBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _TopBtn(
                    icon: Icons.receipt_long_rounded,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LogScreen())),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.touch_app_rounded, color: Color(0xFF2D9CDB), size: 16),
                      SizedBox(width: 6),
                      Text('Tap to detect',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // Capturing overlay
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2D9CDB)),
                    SizedBox(height: 16),
                    Text('Detecting objects on-device…',
                        style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

          // Bottom hint
          if (_isInitialized && !_isCapturing)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: const Text(
                  'Tap anywhere to capture and detect objects',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black54,
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Color(0xFF2D9CDB)),
      SizedBox(height: 16),
      Text('Starting camera…', style: TextStyle(color: Colors.white70, fontSize: 14)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 64),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}
