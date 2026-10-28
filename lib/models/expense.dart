import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String name;
  final double qty;

  /// Line total in taka (not per unit).
  final double amount;
  final DateTime date;
  final bool paid;
  final DateTime? paidAt;
  final String? paidBy;

  /// Expenses marked paid together share one paymentId.
  final String? paymentId;
  final String? createdBy;
  final String? createdByEmail;

  const Expense({
    this.id,
    required this.name,
    required this.qty,
    required this.amount,
    required this.date,
    this.paid = false,
    this.paidAt,
    this.paidBy,
    this.paymentId,
    this.createdBy,
    this.createdByEmail,
  });

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Expense(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      qty: ((data['qty'] as num?) ?? 1).toDouble(),
      amount: (data['amount'] as num).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      paid: (data['paid'] as bool?) ?? false,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      paidBy: data['paidBy'] as String?,
      paymentId: data['paymentId'] as String?,
      createdBy: data['createdBy'] as String?,
      createdByEmail: data['createdByEmail'] as String?,
    );
  }

  /// The fields a user edits in the form.
  Map<String, dynamic> toEditableMap() => {
    'name': name,
    'qty': qty,
    'amount': amount,
    'date': Timestamp.fromDate(date),
  };
}

double totalOf(Iterable<Expense> expenses) =>
    expenses.fold(0.0, (total, e) => total + e.amount);
