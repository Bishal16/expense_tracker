import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/expense.dart';
import '../services/csv_export.dart';
import '../services/expense_repository.dart';
import 'expense_form.dart';

/// Paid expenses, grouped by the payment they were marked paid in.
class HistoryScreen extends StatelessWidget {
  final ExpenseRepository repo;
  final User user;
  final bool isAdmin;

  const HistoryScreen({
    super.key,
    required this.repo,
    required this.user,
    required this.isAdmin,
  });

  /// Groups in order of first appearance; [paid] is already sorted by paidAt.
  static List<List<Expense>> _groupByPayment(List<Expense> paid) {
    final groups = <String, List<Expense>>{};
    for (final e in paid) {
      groups.putIfAbsent(e.paymentId ?? e.id!, () => []).add(e);
    }
    return groups.values.toList();
  }

  static String _items(List<Expense> group) =>
      '${group.length} expense${group.length == 1 ? '' : 's'}'
      ' (${taka(totalOf(group))})';

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _undoPayment(BuildContext context, List<Expense> group) async {
    if (await _confirm(
      context,
      'Undo this payment?',
      '${_items(group)} will move back to unpaid.',
      'Mark unpaid',
    )) {
      await repo.markUnpaid(group.map((e) => e.id!));
    }
  }

  Future<void> _deletePayment(BuildContext context, List<Expense> group) async {
    if (await _confirm(
      context,
      'Delete this payment?',
      '${_items(group)} will be permanently deleted.',
      'Delete',
    )) {
      await repo.deleteAll(group.map((e) => e.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paid history')),
      body: StreamBuilder<List<Expense>>(
        stream: repo.watchPaid(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = _groupByPayment(snap.data!);
          if (groups.isEmpty) {
            return const Center(child: Text('No payments yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Total paid: ${taka(totalOf(snap.data!))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final g in groups) _paymentCard(context, g),
            ],
          );
        },
      ),
    );
  }

  Widget _paymentCard(BuildContext context, List<Expense> group) {
    final first = group.first;
    final paidAt = first.paidAt ?? first.date;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(
              'Paid ${DateFormat.yMMMd().add_jm().format(paidAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'by ${shortName(first.paidBy)}'
              ' · ${group.length} item${group.length == 1 ? '' : 's'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  taka(totalOf(group)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isAdmin)
                  PopupMenuButton<void>(
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: () => _undoPayment(context, group),
                        child: const Text('Mark all unpaid'),
                      ),
                      PopupMenuItem(
                        onTap: () => shareExpensesCsv(
                          group,
                          'payment_${fileStamp(paidAt)}',
                        ),
                        child: const Text('Export CSV'),
                      ),
                      PopupMenuItem(
                        onTap: () => _deletePayment(context, group),
                        child: const Text('Delete payment'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final e in group)
            ListTile(
              dense: true,
              title: Text(e.name),
              subtitle: Text(
                'Qty ${qty(e.qty)} · ${DateFormat.yMMMd().format(e.date)}',
              ),
              trailing: Text(taka(e.amount)),
              onTap: isAdmin
                  ? () => showExpenseForm(
                      context,
                      repo: repo,
                      user: user,
                      isAdmin: true,
                      initial: e,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
