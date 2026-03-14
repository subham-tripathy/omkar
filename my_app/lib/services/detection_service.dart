import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection_model.dart';

// ─── YOLOv8n on-device inference ─────────────────────────────────────────────
//
// Model:   yolov8n.tflite  (float32, exported from yolov8n.pt via ultralytics)
// Input:   [1, 640, 640, 3]  float32, normalised 0–1, RGB, letterboxed
// Output:  [1, 84, 8400]     float32
//            └ 84 = 4 box coords (cx,cy,w,h in 640-space) + 80 COCO class probs
//            └ 8400 anchor points (stride 8/16/32 grid cells)
//
// Pipeline: decode → confidence filter → per-class NMS → scale to original size

class DetectionService {
  static const String _modelPath  = 'assets/models/yolov8n.tflite';
  static const int    _inputSize  = 640;
  static const double _confThresh = 0.25;   // minimum class probability
  static const double _iouThresh  = 0.45;   // NMS IoU threshold
  static const int    _numClasses = 80;

  static Interpreter? _interpreter;

  // ── 80 COCO class labels (same order as YOLOv8 training) ────────────────
  static const List<String> _labels = [
    'person','bicycle','car','motorcycle','airplane','bus','train','truck',
    'boat','traffic light','fire hydrant','stop sign','parking meter','bench',
    'bird','cat','dog','horse','sheep','cow','elephant','bear','zebra','giraffe',
    'backpack','umbrella','handbag','tie','suitcase','frisbee','skis','snowboard',
    'sports ball','kite','baseball bat','baseball glove','skateboard','surfboard',
    'tennis racket','bottle','wine glass','cup','fork','knife','spoon','bowl',
    'banana','apple','sandwich','orange','broccoli','carrot','hot dog','pizza',
    'donut','cake','chair','couch','potted plant','bed','dining table','toilet',
    'tv','laptop','mouse','remote','keyboard','cell phone','microwave','oven',
    'toaster','sink','refrigerator','book','clock','vase','scissors',
    'teddy bear','hair drier','toothbrush',
  ];

  // ── Initialise interpreter once ──────────────────────────────────────────
  static Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    final modelData = await rootBundle.load(_modelPath);
    final buffer    = modelData.buffer.asUint8List(
        modelData.offsetInBytes, modelData.lengthInBytes);
    _interpreter = Interpreter.fromBuffer(buffer,
        options: InterpreterOptions()..threads = 4);
    _interpreter!.allocateTensors();
  }

  // ── Public API ────────────────────────────────────────────────────────────
  static Future<DetectionResult> detect(Uint8List jpegBytes) async {
    await _ensureLoaded();

    // 1. Decode & letterbox
    final srcImage   = img.decodeJpg(jpegBytes)!;
    final srcW       = srcImage.width;
    final srcH       = srcImage.height;
    final letterbox  = _letterbox(srcImage);
    final padLeft    = letterbox.padLeft;
    final padTop     = letterbox.padTop;
    final scale      = letterbox.scale;

    // 2. Build float32 input tensor [1, 640, 640, 3]
    final inputTensor = _buildInputTensor(letterbox.image);

    // 3. Prepare output tensor [1, 84, 8400]
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    // Some ultralytics exports are [1,84,8400]; a few are [1,8400,84] — handle both
    final bool transposed = outputShape[1] == 8400;
    final int rows   = transposed ? 8400 : 84;
    final int cols   = transposed ? 84   : 8400;
    final rawOutput  = List.generate(1,
        (_) => List.generate(rows, (_) => List<double>.filled(cols, 0.0)));

    // 4. Run inference
    _interpreter!.run(inputTensor, rawOutput);

    // 5. Decode predictions
    final detections = transposed
        ? _decodeTransposed(rawOutput[0])   // [8400, 84]
        : _decode(rawOutput[0]);            // [84, 8400]

    // 6. Per-class NMS
    final kept = _nms(detections);

    // 7. Scale boxes from 640-space back to original image pixels
    final objects = <DetectedObjectInfo>[];
    for (int i = 0; i < kept.length; i++) {
      final d = kept[i];

      // Remove letterbox padding then divide by scale
      final x1 = ((d.x1 - padLeft) / scale).clamp(0, srcW.toDouble());
      final y1 = ((d.y1 - padTop)  / scale).clamp(0, srcH.toDouble());
      final x2 = ((d.x2 - padLeft) / scale).clamp(0, srcW.toDouble());
      final y2 = ((d.y2 - padTop)  / scale).clamp(0, srcH.toDouble());

      objects.add(DetectedObjectInfo(
        x:          x1 / srcW,
        y:          y1 / srcH,
        width:      (x2 - x1) / srcW,
        height:     (y2 - y1) / srcH,
        label:      d.label,
        confidence: double.parse(d.confidence.toStringAsFixed(2)),
        index:      i,
        pixelRect:  _Rect(x1.toDouble(), y1.toDouble(), (x2 - x1).toDouble(), (y2 - y1).toDouble()),
      ));
    }

    return DetectionResult(
        objects: objects, imageWidth: srcW, imageHeight: srcH);
  }

  // ── Letterboxing ─────────────────────────────────────────────────────────
  static _LetterboxResult _letterbox(img.Image src) {
    final scale  = min(_inputSize / src.width, _inputSize / src.height);
    final newW   = (src.width  * scale).round();
    final newH   = (src.height * scale).round();
    final padL   = (_inputSize - newW) ~/ 2;
    final padT   = (_inputSize - newH) ~/ 2;

    final resized = img.copyResize(src, width: newW, height: newH,
        interpolation: img.Interpolation.linear);

    // Fill canvas with grey (YOLOv8 canonical padding colour)
    final canvas = img.Image(width: _inputSize, height: _inputSize,
        numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(canvas, resized, dstX: padL, dstY: padT);

    return _LetterboxResult(canvas, scale, padL.toDouble(), padT.toDouble());
  }

  // ── Build float32 input [1, 640, 640, 3] ─────────────────────────────────
  static List _buildInputTensor(img.Image image) {
    // Outer list = batch (1), then H, then W, then C
    final tensor = List.generate(
      1, (_) => List.generate(
        _inputSize, (y) => List.generate(
          _inputSize, (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
    return tensor;
  }

  // ── Decode output [84, 8400] ──────────────────────────────────────────────
  static List<_Detection> _decode(List<List<double>> output) {
    // output[0..3][i] = cx, cy, w, h in 640-space
    // output[4..83][i] = class probabilities
    final detections = <_Detection>[];
    final numAnchors = output[0].length;  // 8400

    for (int i = 0; i < numAnchors; i++) {
      // Find best class
      double bestConf = 0;
      int bestCls     = 0;
      for (int c = 0; c < _numClasses; c++) {
        final score = output[4 + c][i];
        if (score > bestConf) { bestConf = score; bestCls = c; }
      }
      if (bestConf < _confThresh) continue;

      final cx = output[0][i];
      final cy = output[1][i];
      final w  = output[2][i];
      final h  = output[3][i];

      detections.add(_Detection(
        x1:         cx - w / 2,
        y1:         cy - h / 2,
        x2:         cx + w / 2,
        y2:         cy + h / 2,
        confidence: bestConf,
        classId:    bestCls,
        label:      _labels[bestCls],
      ));
    }
    return detections;
  }

  // ── Decode transposed output [8400, 84] ───────────────────────────────────
  static List<_Detection> _decodeTransposed(List<List<double>> output) {
    final detections = <_Detection>[];
    for (final row in output) {
      double bestConf = 0;
      int bestCls     = 0;
      for (int c = 0; c < _numClasses; c++) {
        if (row[4 + c] > bestConf) { bestConf = row[4 + c]; bestCls = c; }
      }
      if (bestConf < _confThresh) continue;

      final cx = row[0], cy = row[1], w = row[2], h = row[3];
      detections.add(_Detection(
        x1:         cx - w / 2,
        y1:         cy - h / 2,
        x2:         cx + w / 2,
        y2:         cy + h / 2,
        confidence: bestConf,
        classId:    bestCls,
        label:      _labels[bestCls],
      ));
    }
    return detections;
  }

  // ── Per-class Non-Maximum Suppression ────────────────────────────────────
  static List<_Detection> _nms(List<_Detection> detections) {
    if (detections.isEmpty) return [];

    // Group by class
    final byClass = <int, List<_Detection>>{};
    for (final d in detections) {
      byClass.putIfAbsent(d.classId, () => []).add(d);
    }

    final result = <_Detection>[];
    for (final group in byClass.values) {
      group.sort((a, b) => b.confidence.compareTo(a.confidence));
      final suppressed = List<bool>.filled(group.length, false);

      for (int i = 0; i < group.length; i++) {
        if (suppressed[i]) continue;
        result.add(group[i]);
        for (int j = i + 1; j < group.length; j++) {
          if (!suppressed[j] && _iou(group[i], group[j]) > _iouThresh) {
            suppressed[j] = true;
          }
        }
      }
    }
    return result;
  }

  static double _iou(_Detection a, _Detection b) {
    final interX1 = max(a.x1, b.x1);
    final interY1 = max(a.y1, b.y1);
    final interX2 = min(a.x2, b.x2);
    final interY2 = min(a.y2, b.y2);

    if (interX2 <= interX1 || interY2 <= interY1) return 0;

    final interArea = (interX2 - interX1) * (interY2 - interY1);
    final aArea     = (a.x2 - a.x1) * (a.y2 - a.y1);
    final bArea     = (b.x2 - b.x1) * (b.y2 - b.y1);
    return interArea / (aArea + bArea - interArea);
  }

  static Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}

// ── Internal data classes ─────────────────────────────────────────────────────

class _LetterboxResult {
  final img.Image image;
  final double scale, padLeft, padTop;
  _LetterboxResult(this.image, this.scale, this.padLeft, this.padTop);
}

class _Detection {
  final double x1, y1, x2, y2, confidence;
  final int classId;
  final String label;
  _Detection({
    required this.x1, required this.y1,
    required this.x2, required this.y2,
    required this.confidence,
    required this.classId,
    required this.label,
  });
}

// Simple rect for pixel coords (avoids dart:ui dependency in service layer)
class _Rect {
  final double left, top, width, height;
  _Rect(this.left, this.top, this.width, this.height);
}
