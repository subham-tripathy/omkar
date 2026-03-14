import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detection_model.dart';

// ─── Groq Vision-based Object Detection ──────────────────────────────────────
//
// Uses Groq's vision model (llama-4-scout) to analyse a JPEG image and return
// a structured list of detected objects with:
//   - Specific brand/model names   e.g. "Acer Aspire laptop", "iPhone 15 Pro"
//   - Normalised bounding boxes    (x, y, width, height) all in 0..1 range
//   - Confidence scores            0..1
//
// The model is prompted to respond ONLY with a JSON array so we can parse it
// directly — no markdown fences, no preamble.

const _groqApiKey =
    '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';
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
// llama-4-scout supports vision and fast inference on Groq
const _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

class DetectionService {
  /// Sends [jpegBytes] to Groq vision and returns a [DetectionResult].
  static Future<DetectionResult> detect(Uint8List jpegBytes) async {
    final base64Image = base64Encode(jpegBytes);

    final payload = {
      'model': _visionModel,
      'max_tokens': 1024,
      'temperature': 0.1,
      'messages': [
        {
          'role': 'system',
          'content': '''You are an expert visual object detector.
Analyse the image and detect ALL visible objects.

IMPORTANT RULES:
1. Be as SPECIFIC as possible. Use brand names, models, colours, and distinguishing features.
   - Bad: "laptop"    Good: "Acer Aspire 5 laptop (silver)"
   - Bad: "phone"     Good: "iPhone 15 Pro (black)"
   - Bad: "cup"       Good: "white ceramic coffee mug"
   - Bad: "car"       Good: "red Toyota Camry sedan"
   - Bad: "person"    Good: "person wearing blue hoodie"
2. Return ONLY a valid JSON array — no markdown, no explanation, no extra text.
3. Each item in the array must have exactly these fields:
   - "label": string  (specific object name)
   - "confidence": number 0.0-1.0
   - "x": number 0.0-1.0  (left edge of bounding box, fraction of image width)
   - "y": number 0.0-1.0  (top edge of bounding box, fraction of image height)
   - "width": number 0.0-1.0  (box width as fraction of image width)
   - "height": number 0.0-1.0 (box height as fraction of image height)
4. If nothing is visible, return an empty array: []

Example output format (do NOT copy these values):
[{"label":"Dell XPS 15 laptop (black)","confidence":0.95,"x":0.1,"y":0.2,"width":0.4,"height":0.3}]'''
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              },
            },
            {
              'type': 'text',
              'text': 'Detect all objects in this image. Return only the JSON array.',
            },
          ],
        },
      ],
    };

    final response = await http
        .post(
          Uri.parse(_groqUrl),
          headers: {
            'Authorization': 'Bearer $_groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final rawContent =
        (responseData['choices'][0]['message']['content'] as String).trim();

    // Strip any accidental markdown fences the model may have added
    final cleaned = rawContent
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    List<dynamic> items;
    try {
      items = jsonDecode(cleaned) as List<dynamic>;
    } catch (_) {
      items = [];
    }

    // Use a virtual 1000x1000 canvas — normalised coords handle the rendering.
    const virtualSize = 1000;

    final objects = <DetectedObjectInfo>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;

      final x    = _toDouble(item['x']).clamp(0.0, 1.0);
      final y    = _toDouble(item['y']).clamp(0.0, 1.0);
      final w    = _toDouble(item['width']).clamp(0.0, 1.0 - x);
      final h    = _toDouble(item['height']).clamp(0.0, 1.0 - y);
      final conf = _toDouble(item['confidence']).clamp(0.0, 1.0);
      final label = (item['label'] as String? ?? 'Unknown object').trim();

      objects.add(DetectedObjectInfo(
        x:          x,
        y:          y,
        width:      w,
        height:     h,
        label:      label,
        confidence: double.parse(conf.toStringAsFixed(2)),
        index:      i,
        pixelRect:  null,
      ));
    }

    return DetectionResult(
      objects:     objects,
      imageWidth:  virtualSize,
      imageHeight: virtualSize,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
