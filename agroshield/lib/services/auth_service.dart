import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  final _analytics = FirebaseAnalytics.instance;

  // Returns Firebase User on success. Throws on failure.
  Future<User> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Create or update users/{uid} in Firestore
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snap = await userDoc.get();
    if (!snap.exists) {
      await userDoc.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'authType': 'google',
      });
    }

    // Persist device_id for analytics
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId);

    await _analytics.setUserId(id: deviceId);
    await _analytics.logEvent(name: 'sign_in_google', parameters: {
      'device_id': deviceId,
    });

    return user;
  }

  // Guest path: generates anonymous UUID, persists locally.
  Future<String> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId);
    await prefs.setString('auth_type', 'guest');
    await _analytics.setUserId(id: deviceId);
    return deviceId;
  }

  bool get isSignedIn => _auth.currentUser != null;

  String? get currentUid => _auth.currentUser?.uid;

  Future<String?> getGuestDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_type') == 'guest';
  }
}
