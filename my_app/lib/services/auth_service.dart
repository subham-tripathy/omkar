import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── AppUser model ────────────────────────────────────────────────────────────
// Wraps Firestore user data. Firebase Auth handles passwords/sessions.

class AppUser {
  final String uid;
  final String username;
  final String email;
  final String role; // 'admin' | 'user'
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) =>
      AppUser(
        uid: uid,
        username: data['username'] as String? ?? '',
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? 'user',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

// ─── AuthService ──────────────────────────────────────────────────────────────

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static final _users = _db.collection('users');

  // ── Sign up ───────────────────────────────────────────────────────────────
  // Firebase Auth uses email/password. We store a chosen username in Firestore.
  static Future<String?> signUp(
      String username, String email, String password) async {
    username = username.trim();
    email = email.trim();

    if (username.length < 3) return 'Username must be at least 3 characters.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    // Check username uniqueness in Firestore
    final existing = await _users
        .where('usernameLower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return 'Username already taken.';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;

      // Save profile to Firestore
      await _users.doc(uid).set({
        'uid': uid,
        'username': username,
        'usernameLower': username.toLowerCase(),
        'email': email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  static Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() => _auth.signOut();

  // ── Current user ──────────────────────────────────────────────────────────
  // Returns null if not logged in, fetches Firestore profile for role/username.
  static Future<AppUser?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _fetchProfile(firebaseUser.uid);
  }

  static Future<AppUser?> _fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(uid, doc.data()!);
  }

  // Stream so dashboards can react to auth changes in real time
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Admin helpers ─────────────────────────────────────────────────────────
  static Future<List<AppUser>> allUsers() async {
    final snap = await _users.orderBy('createdAt').get();
    return snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList();
  }

  static Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
    // Also delete their logs sub-collection
    final logs = await _db
        .collection('logs')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in logs.docs) {
      await doc.reference.delete();
    }
    // Note: deleting the Firebase Auth account itself requires the Admin SDK
    // or the user to be signed in. We just remove their Firestore data here.
  }

  // ── Error messages ────────────────────────────────────────────────────────
  static String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'That email is already registered.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'user-not-found':       return 'No account found with that email.';
      case 'wrong-password':       return 'Incorrect password.';
      case 'invalid-credential':   return 'Incorrect email or password.';
      case 'too-many-requests':    return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'No internet connection.';
      default:                     return 'Something went wrong ($code).';
    }
  }
}
