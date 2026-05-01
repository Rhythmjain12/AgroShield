import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/prefs_keys.dart';

/// Abstracts storage: Firestore for signed-in users, SharedPreferences for guests.
///
/// Signed-in path also maintains a local SharedPrefs cache so that:
///   • loadProfile() can fall back to cache when offline.
///   • Settings screen never shows "Not set" due to a transient network error.
class FarmProfileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> saveProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Primary write: Firestore (merge so unrelated fields are preserved)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('farmData')
          .doc('profile')
          .set(data, SetOptions(merge: true));

      // Write-through: keep local cache in sync for offline reads
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PrefsKeys.farmProfile);
      final existing = raw != null
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      existing.addAll(data); // mirrors Firestore merge: true
      await prefs.setString(PrefsKeys.farmProfile, jsonEncode(existing));
    } else {
      // Guest path: SharedPrefs is the only store; replace entire blob
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.farmProfile, jsonEncode(data));
    }
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('farmData')
            .doc('profile')
            .get();
        return snap.data();
      } catch (_) {
        // Offline or network error — serve local cache so UI shows real values
        return _loadFromPrefs();
      }
    } else {
      return _loadFromPrefs();
    }
  }

  Future<Map<String, dynamic>?> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.farmProfile);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }
}
