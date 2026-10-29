import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/theme_prefs.dart';

/// Each user's look, stored in prefs/{uid} so it follows them to any phone.
class PrefsRepository {
  final CollectionReference<Map<String, dynamic>> _prefs = FirebaseFirestore
      .instance
      .collection('prefs');

  /// The user's saved look, or null if they never changed anything.
  Stream<ThemePrefs?> watch(String uid, String? email) {
    final base = ThemePrefs.defaults(admin: isAdminEmail(email));
    return _prefs
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? ThemePrefs.fromMap(d.data()!, base) : null)
        // A missing rule or offline start shouldn't break the app's theme.
        .handleError((_) {});
  }

  Future<void> save(String uid, ThemePrefs prefs) =>
      _prefs.doc(uid).set(prefs.toMap());

  Future<void> reset(String uid) => _prefs.doc(uid).delete();
}
