import 'package:cloud_firestore/cloud_firestore.dart';

import '../format.dart' as fmt;

class Expense {
  final String? id;
  final String name;

  /// Optional quantity and unit of measure, e.g. 2 + "kg".
  final double? qty;
  final String? unit;

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
    this.qty,
    this.unit,
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
      qty: (data['qty'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
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
    'unit': unit,
    'amount': amount,
    'date': Timestamp.fromDate(date),
  };
}

/// Units offered in the add form.
const units = ['kg', 'g', 'litre', 'ml', 'pcs', 'dozen', 'pack', 'box'];

extension ExpenseDetails on Expense {
  /// "2 kg", "3", "kg" or null when neither is set.
  String? get qtyLabel {
    final parts = [if (qty != null) fmt.qty(qty!), ?unit];
    return parts.isEmpty ? null : parts.join(' ');
  }
}

double totalOf(Iterable<Expense> expenses) =>
    expenses.fold(0.0, (total, e) => total + e.amount);
