import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus { pending, approved, blocked }

/// An account that has asked for access. The admin is not stored here.
class AppUser {
  final String uid;
  final String email;
  final UserStatus status;
  final DateTime? requestedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.status,
    this.requestedAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      status:
          UserStatus.values.asNameMap()[data['status']] ?? UserStatus.pending,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
    );
  }
}
