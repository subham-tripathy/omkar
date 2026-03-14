import 'package:cloud_firestore/cloud_firestore.dart';

class DetectionLogEntry {
  final String id;
  final String objectName;
  final DateTime timestamp;
  final String uid;
  final String username;

  DetectionLogEntry({
    required this.id,
    required this.objectName,
    required this.timestamp,
    required this.uid,
    required this.username,
  });

  factory DetectionLogEntry.fromFirestore(
      String id, Map<String, dynamic> data) =>
      DetectionLogEntry(
        id: id,
        objectName: data['objectName'] as String? ?? '',
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        uid: data['uid'] as String? ?? '',
        username: data['username'] as String? ?? 'unknown',
      );
}

class LogService {
  static final _logs = FirebaseFirestore.instance.collection('logs');

  /// Save detected objects for the current user.
  static Future<void> logDetections({
    required List<String> objectNames,
    required String uid,
    required String username,
  }) async {
    if (objectNames.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final now = Timestamp.now();
    for (final name in objectNames) {
      final ref = _logs.doc();
      batch.set(ref, {
        'objectName': name,
        'uid': uid,
        'username': username,
        'timestamp': now,
      });
    }
    await batch.commit();
  }

  /// Logs for a specific user, newest first.
  static Future<List<DetectionLogEntry>> getLogsForUser(String uid) async {
    final snap = await _logs
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();
    return snap.docs
        .map((d) => DetectionLogEntry.fromFirestore(d.id, d.data()))
        .toList();
  }

  /// All logs across all users (admin view), newest first.
  static Future<List<DetectionLogEntry>> getAllLogs() async {
    final snap = await _logs
        .orderBy('timestamp', descending: true)
        .limit(500)
        .get();
    return snap.docs
        .map((d) => DetectionLogEntry.fromFirestore(d.id, d.data()))
        .toList();
  }

  /// Delete all logs for a user.
  static Future<void> clearLogsForUser(String uid) async {
    final snap = await _logs.where('uid', isEqualTo: uid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
