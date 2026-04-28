import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Abstracts storage: Firestore for signed-in users, SharedPreferences for guests.
class FarmProfileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const _kFarmProfile = 'farm_profile';

  Future<void> saveProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('farmData')
          .doc('profile')
          .set(data, SetOptions(merge: true));
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFarmProfile, jsonEncode(data));
    }
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('farmData')
          .doc('profile')
          .get();
      return snap.data();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFarmProfile);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    }
  }
}
