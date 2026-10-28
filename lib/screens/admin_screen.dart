import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../format.dart';
import '../models/app_user.dart';
import '../models/expense.dart';
import '../services/csv_export.dart';
import '../services/expense_repository.dart';
import '../services/user_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Admin-only: summary, user approvals, bulk actions and CSV export.
class AdminScreen extends StatefulWidget {
  final ExpenseRepository repo;
  final User user;

  const AdminScreen({super.key, required this.repo, required this.user});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _usersRepo = UserRepository();
  late final Stream<List<Expense>> _expenses = widget.repo.watchAll();
  late final Stream<List<AppUser>> _users = _usersRepo.watchAll();

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: StreamBuilder<List<Expense>>(
            stream: _expenses,
            builder: (context, expSnap) => StreamBuilder<List<AppUser>>(
              stream: _users,
              builder: (context, userSnap) {
                final error = expSnap.error ?? userSnap.error;
                final ready = expSnap.hasData && userSnap.hasData;
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const PageHeader(title: 'Admin panel'),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Error: $error'),
                      )
                    else if (!ready)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(
                              'Summary',
                              Icons.insights_rounded,
                              _summary(expSnap.data!),
                            ),
                            _section(
                              'Users',
                              Icons.group_rounded,
                              _usersList(userSnap.data!),
                            ),
                            _section(
                              'Bulk actions',
                              Icons.bolt_rounded,
                              _bulkActions(expSnap.data!),
                            ),
                            _section(
                              'Export CSV',
                              Icons.file_download_outlined,
                              _export(expSnap.data!),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.style.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        SoftCard(padding: EdgeInsets.zero, child: child),
      ],
    ),
  );

  // ---- Summary ----

  Widget _summary(List<Expense> all) {
    final unpaid = all.where((e) => !e.paid).toList();
    final paid = all.where((e) => e.paid).toList();
    final now = DateTime.now();
    final paidThisMonth = paid.where((e) {
      final at = e.paidAt ?? e.date;
      return at.year == now.year && at.month == now.month;
    });

    final byUser = <String, List<Expense>>{};
    for (final e in all) {
      byUser.putIfAbsent(e.createdByEmail ?? 'unknown', () => []).add(e);
    }
    final users = byUser.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _stat('Unpaid', totalOf(unpaid), '${unpaid.length} items'),
              _stat('Paid', totalOf(paid), '${paid.length} items'),
              _stat(
                'Paid in ${DateFormat.MMM().format(now)}',
                totalOf(paidThisMonth),
                '${paidThisMonth.length} items',
              ),
            ],
          ),
          if (users.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              'Added by user',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final u in users)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${shortName(u)}${isAdminEmail(u) ? ' (admin)' : ''}',
                      ),
                    ),
                    Text(
                      '${taka(totalOf(byUser[u]!))} · '
                      '${taka(totalOf(byUser[u]!.where((e) => !e.paid)))} unpaid',
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, double amount, String sub) {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              style.header.first.withValues(alpha: 0.16),
              style.header.last.withValues(alpha: 0.16),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                taka(amount),
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: style.accent,
                ),
              ),
            ),
            Text(sub, style: text.bodySmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // ---- Users ----

  Widget _usersList(List<AppUser> users) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.admin_panel_settings),
          title: Text(widget.user.email ?? adminEmail),
          subtitle: const Text('Admin · always allowed'),
        ),
        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('No one else has signed in yet.'),
          ),
        for (final u in users)
          ListTile(
            leading: Icon(
              switch (u.status) {
                UserStatus.approved => Icons.check_circle,
                UserStatus.pending => Icons.hourglass_top,
                UserStatus.blocked => Icons.block,
              },
              color: switch (u.status) {
                UserStatus.approved => Colors.green,
                UserStatus.pending => Colors.orange,
                UserStatus.blocked => Colors.red,
              },
            ),
            title: Text(u.email),
            subtitle: Text(switch (u.status) {
              UserStatus.approved => 'Approved',
              UserStatus.pending => 'Waiting for approval',
              UserStatus.blocked => 'Blocked',
            }),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (u.status != UserStatus.approved)
                  TextButton(
                    onPressed: () => _run(
                      () => _usersRepo.setStatus(u.uid, UserStatus.approved),
                      '${u.email} approved',
                    ),
                    child: const Text('Approve'),
                  ),
                if (u.status != UserStatus.blocked)
                  TextButton(
                    onPressed: () async {
                      if (await _confirm(
                        'Block ${u.email}?',
                        'They will no longer be able to see or change any expenses.',
                        'Block',
                      )) {
                        await _run(
                          () => _usersRepo.setStatus(u.uid, UserStatus.blocked),
                          '${u.email} blocked',
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Block'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- Bulk actions ----

  Widget _bulkActions(List<Expense> all) {
    final unpaid = all.where((e) => !e.paid).toList();
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.done_all),
          title: const Text('Mark all unpaid as paid'),
          subtitle: Text('${unpaid.length} items · ${taka(totalOf(unpaid))}'),
          enabled: unpaid.isNotEmpty,
          onTap: () async {
            if (await _confirm(
              'Mark everything paid?',
              '${unpaid.length} expenses totalling ${taka(totalOf(unpaid))} '
                  'will move to paid history as one payment.',
              'Mark paid',
            )) {
              await _run(
                () => widget.repo.markPaid(
                  unpaid.map((e) => e.id!),
                  widget.user.email,
                ),
                'Marked ${unpaid.length} expenses paid',
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep),
          title: const Text('Clear old paid history'),
          subtitle: const Text('Permanently delete payments older than…'),
          onTap: () => _clearOld(all),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          subtitle: Text(
            'To delete or export a single payment, use its ⋮ menu in Paid history.',
          ),
        ),
      ],
    );
  }

  Future<void> _clearOld(List<Expense> all) async {
    final months = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Delete paid expenses older than'),
        children: [
          for (final m in const [6, 12, 24])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text('$m months'),
            ),
        ],
      ),
    );
    if (months == null || !mounted) return;
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - months, now.day);
    final old = all
        .where((e) => e.paid && (e.paidAt ?? e.date).isBefore(cutoff))
        .toList();
    if (old.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nothing paid before ${DateFormat.yMMMd().format(cutoff)}',
          ),
        ),
      );
      return;
    }
    if (await _confirm(
      'Delete ${old.length} paid expenses?',
      'Everything paid before ${DateFormat.yMMMd().format(cutoff)} '
          '(${taka(totalOf(old))}) will be permanently deleted. '
          'Export a CSV first if you want a copy.',
      'Delete',
    )) {
      await _run(
        () => widget.repo.deleteAll(old.map((e) => e.id!)),
        'Deleted ${old.length} old expenses',
      );
    }
  }

  // ---- Export ----

  Widget _export(List<Expense> all) {
    final byDate = [...all]..sort((a, b) => b.date.compareTo(a.date));
    Widget tile(String label, String file, List<Expense> items) => ListTile(
      leading: const Icon(Icons.file_download),
      title: Text(label),
      subtitle: Text('${items.length} items · ${taka(totalOf(items))}'),
      enabled: items.isNotEmpty,
      onTap: () => _run(
        () => shareExpensesCsv(items, '${file}_${fileStamp(DateTime.now())}'),
        'CSV ready to share',
      ),
    );
    return Column(
      children: [
        tile('All expenses', 'all_expenses', byDate),
        tile('Unpaid only', 'unpaid', byDate.where((e) => !e.paid).toList()),
        tile('Paid only', 'paid', byDate.where((e) => e.paid).toList()),
      ],
    );
  }
}
