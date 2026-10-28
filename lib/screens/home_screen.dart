import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../format.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/expense_repository.dart';
import 'admin_screen.dart';
import 'expense_form.dart';
import 'history_screen.dart';

/// Landing page: unpaid expenses and the total still owed.
class HomeScreen extends StatefulWidget {
  final User user;
  final AuthService auth;

  const HomeScreen({super.key, required this.user, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ExpenseRepository();
  late final Stream<List<Expense>> _unpaid = _repo.watchUnpaid();
  late final bool _isAdmin = isAdminEmail(widget.user.email);
  final Set<String> _selected = {};

  bool _canEdit(Expense e) => _isAdmin || e.createdBy == widget.user.uid;

  void _toggle(Expense e) => setState(
    () => _selected.contains(e.id)
        ? _selected.remove(e.id)
        : _selected.add(e.id!),
  );

  void _open(Expense e) => showExpenseForm(
    context,
    repo: _repo,
    user: widget.user,
    isAdmin: _isAdmin,
    initial: e,
  );

  void _add() => showExpenseForm(
    context,
    repo: _repo,
    user: widget.user,
    isAdmin: _isAdmin,
  );

  Future<void> _markPaid(List<Expense> chosen) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text(
          '${chosen.length} expense${chosen.length == 1 ? '' : 's'}'
          ' totalling ${taka(totalOf(chosen))} will move to paid history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.markPaid(chosen.map((e) => e.id!), widget.user.email);
      setState(_selected.clear);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: _unpaid,
      builder: (context, snap) {
        final expenses = snap.data ?? const <Expense>[];
        // Drop selections that disappeared (paid or deleted elsewhere).
        _selected.removeWhere((id) => !expenses.any((e) => e.id == id));
        final chosen = expenses.where((e) => _selected.contains(e.id)).toList();
        final selecting = chosen.isNotEmpty;

        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(_selected.clear);
          },
          child: Scaffold(
            appBar: selecting
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_selected.clear),
                    ),
                    title: Text('${chosen.length} selected'),
                    actions: [
                      TextButton(
                        onPressed: () => setState(
                          () => _selected.addAll(expenses.map((e) => e.id!)),
                        ),
                        child: const Text('Select all'),
                      ),
                    ],
                  )
                : AppBar(
                    title: const Text('Unpaid'),
                    actions: [
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings),
                          tooltip: 'Admin panel',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminScreen(repo: _repo, user: widget.user),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'Paid history',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(
                              repo: _repo,
                              user: widget.user,
                              isAdmin: _isAdmin,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Sign out (${widget.user.email})',
                        onPressed: widget.auth.signOut,
                      ),
                    ],
                  ),
            floatingActionButton: selecting
                ? null
                : FloatingActionButton.extended(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
            bottomNavigationBar: selecting
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        onPressed: () => _markPaid(chosen),
                        icon: const Icon(Icons.check_circle),
                        label: Text('Mark paid · ${taka(totalOf(chosen))}'),
                      ),
                    ),
                  )
                : null,
            body: _body(snap, expenses),
          ),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<List<Expense>> snap, List<Expense> expenses) {
    if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total remaining',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  taka(totalOf(expenses)),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '${expenses.length} unpaid'
                  ' expense${expenses.length == 1 ? '' : 's'}',
                ),
              ],
            ),
          ),
        ),
        if (expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Nothing unpaid 🎉')),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text('Tap the circle to select expenses to mark paid.'),
          ),
        for (final e in expenses) _tile(e),
      ],
    );
  }

  Widget _tile(Expense e) {
    final selected = _selected.contains(e.id);
    final selecting = _selected.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      selected: selected,
      leading: IconButton(
        icon: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
        onPressed: () => _toggle(e),
      ),
      title: Text(e.name),
      subtitle: Text(
        'Qty ${qty(e.qty)} · ${DateFormat.yMMMd().format(e.date)}',
      ),
      trailing: Text(
        taka(e.amount),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () {
        if (selecting || !_canEdit(e)) {
          _toggle(e);
        } else {
          _open(e);
        }
      },
      onLongPress: () => _toggle(e),
    );
  }
}
