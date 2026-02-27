import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://statutory-really-glasses-reveal.trycloudflare.com';

  /// Send image bytes to backend for YOLO detection
  static Future<DetectionResult> detectObjects(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse('$baseUrl/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_base64': base64Image}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DetectionResult.fromJson(data);
    } else {
      throw Exception('Detection failed: ${response.statusCode}');
    }
  }

  /// Get AI explanation for a detected object
  static Future<String> getExplanation(String objectName, String level) async {
    final response = await http.post(
      Uri.parse('$baseUrl/explain'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'object_name': objectName, 'level': level}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['explanation'] as String;
    } else {
      throw Exception('Explanation failed: ${response.statusCode}');
    }
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class DetectedObject {
  final double x; // normalized 0-1
  final double y;
  final double width;
  final double height;
  final String label;
  final double confidence;
  final int index;

  DetectedObject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
    required this.index,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      index: json['index'] as int,
    );
  }

  /// Check if a tap point (normalized 0-1) is inside this bounding box
  bool containsPoint(double tapX, double tapY) {
    return tapX >= x &&
        tapX <= x + width &&
        tapY >= y &&
        tapY <= y + height;
  }

  String get displayLabel =>
      label[0].toUpperCase() + label.substring(1).replaceAll('_', ' ');

  String get confidencePercent => '${(confidence * 100).round()}%';
}

class DetectionResult {
  final List<DetectedObject> objects;
  final int imageWidth;
  final int imageHeight;

  DetectionResult({
    required this.objects,
    required this.imageWidth,
    required this.imageHeight,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final objectList = (json['objects'] as List)
        .map((e) => DetectedObject.fromJson(e as Map<String, dynamic>))
        .toList();
    return DetectionResult(
      objects: objectList,
      imageWidth: json['image_width'] as int,
      imageHeight: json['image_height'] as int,
    );
  }
}
