import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DetectionLogEntry {
  final String objectName;
  final DateTime timestamp;

  DetectionLogEntry({required this.objectName, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'objectName': objectName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DetectionLogEntry.fromJson(Map<String, dynamic> json) =>
      DetectionLogEntry(
        objectName: json['objectName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class LogService {
  static const String _key = 'detection_logs';

  /// Append multiple detected object names with the current timestamp.
  static Future<void> logDetections(List<String> objectNames) async {
    if (objectNames.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await getLogs();
    final now = DateTime.now();
    final newEntries = objectNames
        .map((name) => DetectionLogEntry(objectName: name, timestamp: now))
        .toList();
    final all = [...existing, ...newEntries];
    // Keep at most 500 entries to avoid unbounded growth
    final trimmed = all.length > 500 ? all.sublist(all.length - 500) : all;
    final encoded =
        jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Return all logs, newest first.
  static Future<List<DetectionLogEntry>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final entries = decoded
        .map((e) => DetectionLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return entries.reversed.toList(); // newest first
  }

  /// Clear all logs.
  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
