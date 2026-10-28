import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

/// One shared expense list for both users.
class ExpenseRepository {
  final CollectionReference<Map<String, dynamic>> _expenses = FirebaseFirestore
      .instance
      .collection('expenses');

  /// Unpaid expenses, newest first.
  Stream<List<Expense>> watchUnpaid() => _watch(false, (a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.name.compareTo(b.name);
  });

  /// Paid expenses, most recently paid first.
  Stream<List<Expense>> watchPaid() => _watch(true, (a, b) {
    final byPaid = (b.paidAt ?? b.date).compareTo(a.paidAt ?? a.date);
    return byPaid != 0 ? byPaid : b.date.compareTo(a.date);
  });

  // Sorting happens on the device so Firestore needs no composite index.
  Stream<List<Expense>> _watch(
    bool paid,
    int Function(Expense, Expense) compare,
  ) => _expenses
      .where('paid', isEqualTo: paid)
      .snapshots()
      .map((snap) => snap.docs.map(Expense.fromDoc).toList()..sort(compare));

  Future<void> add(Expense e, String uid, String? email) => _expenses.add({
    ...e.toEditableMap(),
    'paid': false,
    'createdBy': uid,
    'createdByEmail': email,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> update(Expense e) =>
      _expenses.doc(e.id).update(e.toEditableMap());

  Future<void> delete(String id) => _expenses.doc(id).delete();

  /// Every expense, paid or not. Used by the admin panel.
  Stream<List<Expense>> watchAll() => _expenses.snapshots().map(
    (snap) => snap.docs.map(Expense.fromDoc).toList(),
  );

  /// Marks [ids] paid as one payment.
  Future<void> markPaid(Iterable<String> ids, String? email) {
    final paymentId = _expenses.doc().id;
    final now = Timestamp.now();
    return _writeAll(
      ids,
      (batch, doc) => batch.update(doc, {
        'paid': true,
        'paidAt': now,
        'paidBy': email,
        'paymentId': paymentId,
      }),
    );
  }

  /// Moves [ids] back to unpaid. Admin only.
  Future<void> markUnpaid(Iterable<String> ids) => _writeAll(
    ids,
    (batch, doc) => batch.update(doc, {
      'paid': false,
      'paidAt': FieldValue.delete(),
      'paidBy': FieldValue.delete(),
      'paymentId': FieldValue.delete(),
    }),
  );

  /// Deletes [ids]. Admin only for anything but your own unpaid expenses.
  Future<void> deleteAll(Iterable<String> ids) =>
      _writeAll(ids, (batch, doc) => batch.delete(doc));

  // Firestore batches hold at most 500 writes.
  Future<void> _writeAll(
    Iterable<String> ids,
    void Function(WriteBatch, DocumentReference<Map<String, dynamic>>) write,
  ) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in list.skip(i).take(450)) {
        write(batch, _expenses.doc(id));
      }
      await batch.commit();
    }
  }
}
