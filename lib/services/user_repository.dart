import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Access requests and approvals, stored in users/{uid}.
class UserRepository {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection('users');

  /// The signed-in user's own record; null until they request access.
  Stream<AppUser?> watchMe(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// Creates a pending access request for [user].
  Future<void> requestAccess(User user) => _users.doc(user.uid).set({
    'email': user.email,
    'status': UserStatus.pending.name,
    'requestedAt': FieldValue.serverTimestamp(),
  });

  /// All accounts, oldest request first. Admin only.
  Stream<List<AppUser>> watchAll() => _users.snapshots().map(
    (snap) => snap.docs.map(AppUser.fromDoc).toList()
      ..sort(
        (a, b) => (a.requestedAt ?? DateTime(2000)).compareTo(
          b.requestedAt ?? DateTime(2000),
        ),
      ),
  );

  Future<void> setStatus(String uid, UserStatus status) =>
      _users.doc(uid).update({'status': status.name});
}
