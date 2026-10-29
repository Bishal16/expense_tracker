import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../format.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/expense_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'admin_screen.dart';
import 'expense_form.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

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

  void _toggle(Expense e) {
    HapticFeedback.selectionClick();
    setState(
      () => _selected.contains(e.id)
          ? _selected.remove(e.id)
          : _selected.add(e.id!),
    );
  }

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

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _markPaid(List<Expense> chosen) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.verified_rounded,
          color: context.style.accent,
          size: 40,
        ),
        title: const Text('Mark as paid?'),
        content: Text(
          '${chosen.length} expense${chosen.length == 1 ? '' : 's'}'
          ' totalling ${taka(totalOf(chosen))} will move to paid history.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.markPaid(chosen.map((e) => e.id!), widget.user.email);
      HapticFeedback.mediumImpact();
      setState(_selected.clear);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paid ${taka(totalOf(chosen))} ${context.style.emoji}',
            ),
          ),
        );
      }
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
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: GradientBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                floatingActionButton: selecting
                    ? null
                    : GradientButton(
                        label: 'Add expense',
                        icon: Icons.add_rounded,
                        onPressed: _add,
                      ),
                bottomNavigationBar: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selecting
                      ? _selectionBar(expenses, chosen)
                      : const SizedBox.shrink(),
                ),
                body: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _header(snap, expenses)),
                    ..._body(snap, expenses),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(AsyncSnapshot<List<Expense>> snap, List<Expense> expenses) {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    final name =
        style.displayName ??
        (_isAdmin ? 'Admin' : friendlyName(widget.user.email));
    return GradientHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeGreeting(),
                      style: text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      'Hi, $name ${style.emoji}',
                      style: style.greeting(26).copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (_isAdmin)
                HeaderIconButton(
                  icon: Icons.admin_panel_settings_rounded,
                  tooltip: 'Admin panel',
                  onPressed: () =>
                      _push(AdminScreen(repo: _repo, user: widget.user)),
                ),
              HeaderIconButton(
                icon: Icons.history_rounded,
                tooltip: 'Paid history',
                onPressed: () => _push(
                  HistoryScreen(
                    repo: _repo,
                    user: widget.user,
                    isAdmin: _isAdmin,
                  ),
                ),
              ),
              HeaderIconButton(
                icon: Icons.palette_outlined,
                tooltip: 'Make it yours',
                onPressed: () =>
                    _push(SettingsScreen(user: widget.user, auth: widget.auth)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Total remaining',
            style: text.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              snap.hasData ? taka(totalOf(expenses)) : '—',
              key: ValueKey(totalOf(expenses)),
              style: text.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${expenses.length} unpaid'
              ' expense${expenses.length == 1 ? '' : 's'}',
              style: text.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(
    AsyncSnapshot<List<Expense>> snap,
    List<Expense> expenses,
  ) {
    if (snap.hasError) {
      return [
        SliverFillRemaining(child: Center(child: Text('Error: ${snap.error}'))),
      ];
    }
    if (!snap.hasData) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (expenses.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: _empty())];
    }

    // Group by day; the list is already newest first.
    final days = <String, List<Expense>>{};
    for (final e in expenses) {
      days.putIfAbsent(dayLabel(e.date), () => []).add(e);
    }
    final text = Theme.of(context).textTheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
        sliver: SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Tap a circle to select · long-press works too',
                style: text.bodySmall?.copyWith(color: Colors.black45),
              ),
            ),
            for (final day in days.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: Row(
                  children: [
                    Text(
                      day.key,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      taka(totalOf(day.value)),
                      style: text.labelLarge?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              for (final e in day.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _tile(e),
                ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _empty() {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  style.header.first.withValues(alpha: 0.25),
                  style.header.last.withValues(alpha: 0.25),
                ],
              ),
            ),
            child: Icon(style.motif, size: 56, color: style.accent),
          ),
          const SizedBox(height: 20),
          Text(
            style.playful ? 'All clear, lovely! 🎀' : 'All settled 🎉',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing unpaid right now.\nTap “Add expense” to record a new one.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _tile(Expense e) {
    final selected = _selected.contains(e.id);
    final selecting = _selected.isNotEmpty;
    final text = Theme.of(context).textTheme;
    return SoftCard(
      highlighted: selected,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      onTap: () => selecting || !_canEdit(e) ? _toggle(e) : _open(e),
      onLongPress: () => _toggle(e),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: selected ? 'Deselect ${e.name}' : 'Select ${e.name}',
            child: GestureDetector(
              onTap: () => _toggle(e),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: InitialAvatar(name: e.name, selected: selected),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.qtyLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    e.qtyLabel!,
                    style: text.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          Text(
            taka(e.amount),
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.style.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(List<Expense> expenses, List<Expense> chosen) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear selection',
                onPressed: () => setState(_selected.clear),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${chosen.length} selected',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (chosen.length < expenses.length)
                      GestureDetector(
                        onTap: () => setState(
                          () => _selected.addAll(expenses.map((e) => e.id!)),
                        ),
                        child: Text(
                          'Select all',
                          style: text.labelLarge?.copyWith(
                            color: context.style.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GradientButton(
                label: 'Pay ${taka(totalOf(chosen))}',
                icon: Icons.check_circle_rounded,
                onPressed: () => _markPaid(chosen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
