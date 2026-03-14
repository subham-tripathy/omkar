class DetectedObjectInfo {
  final double x;           // normalised 0..1 (left edge)
  final double y;           // normalised 0..1 (top edge)
  final double width;       // normalised
  final double height;      // normalised
  final String label;       // COCO class name
  final double confidence;  // 0..1
  final int index;
  final dynamic pixelRect;  // _Rect from detection_service (left,top,w,h in px)

  DetectedObjectInfo({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
    required this.index,
    required this.pixelRect,
  });
}

class DetectionResult {
  final List<DetectedObjectInfo> objects;
  final int imageWidth;
  final int imageHeight;

  DetectionResult({
    required this.objects,
    required this.imageWidth,
    required this.imageHeight,
  });

  bool get isEmpty => objects.isEmpty;
}
