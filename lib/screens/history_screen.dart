import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/expense.dart';
import '../services/csv_export.dart';
import '../services/expense_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: StreamBuilder<List<Expense>>(
            stream: repo.watchPaid(),
            builder: (context, snap) {
              final paid = snap.data ?? const <Expense>[];
              final groups = _groupByPayment(paid);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: PageHeader(
                      title: 'Paid history',
                      caption: 'Total paid',
                      figure: snap.hasData ? taka(totalOf(paid)) : '—',
                    ),
                  ),
                  if (snap.hasError)
                    SliverFillRemaining(
                      child: Center(child: Text('Error: ${snap.error}')),
                    )
                  else if (!snap.hasData)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groups.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _empty(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) =>
                            _paymentCard(context, groups[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final style = context.style;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: style.accent),
          const SizedBox(height: 12),
          Text(
            'No payments yet',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paid expenses will show up here.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context, List<Expense> group) {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    final first = group.first;
    final paidAt = first.paidAt ?? first.date;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  style.header.first.withValues(alpha: 0.18),
                  style.header.last.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(style.radius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayLabel(paidAt),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${DateFormat.jm().format(paidAt)}'
                        ' · by ${shortName(first.paidBy)}'
                        ' · ${group.length} item${group.length == 1 ? '' : 's'}',
                        style: text.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  taka(totalOf(group)),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: style.accent,
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<void>(
                    icon: const Icon(Icons.more_vert_rounded),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: () => _undoPayment(context, group),
                        child: const ListTile(
                          leading: Icon(Icons.undo_rounded),
                          title: Text('Mark all unpaid'),
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => shareExpensesCsv(
                          group,
                          'payment_${fileStamp(paidAt)}',
                        ),
                        child: const ListTile(
                          leading: Icon(Icons.file_download_outlined),
                          title: Text('Export CSV'),
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => _deletePayment(context, group),
                        child: const ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Delete payment'),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          for (final e in group)
            ListTile(
              dense: true,
              leading: InitialAvatar(name: e.name),
              title: Text(
                e.name,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [?e.qtyLabel, DateFormat.MMMd().format(e.date)].join(' · '),
              ),
              trailing: Text(
                taka(e.amount),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
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
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
