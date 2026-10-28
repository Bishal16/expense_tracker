import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Opens the add/edit sheet. Saving, deleting and undoing payment happen here.
Future<void> showExpenseForm(
  BuildContext context, {
  required ExpenseRepository repo,
  required User user,
  required bool isAdmin,
  Expense? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExpenseForm(
      repo: repo,
      user: user,
      isAdmin: isAdmin,
      initial: initial,
    ),
  );
}

class _ExpenseForm extends StatefulWidget {
  final ExpenseRepository repo;
  final User user;
  final bool isAdmin;
  final Expense? initial;

  const _ExpenseForm({
    required this.repo,
    required this.user,
    required this.isAdmin,
    this.initial,
  });

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _amount;
  late DateTime _date;
  List<String> _recent = [];
  bool _busy = false;

  Expense? get _initial => widget.initial;

  @override
  void initState() {
    super.initState();
    final e = _initial;
    _name = TextEditingController(text: e?.name ?? '');
    _qty = TextEditingController(text: e == null ? '1' : qty(e.qty));
    _amount = TextEditingController(text: e == null ? '' : qty(e.amount));
    _date = e?.date ?? _today();
    if (e == null) {
      widget.repo.recentNames().then((n) {
        if (mounted) setState(() => _recent = n);
      }, onError: (_) {});
    }
  }

  static DateTime _today() => DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _stepQty(int delta) {
    final current = double.tryParse(_qty.text.trim()) ?? 1;
    final next = (current + delta).clamp(1, 9999).toDouble();
    HapticFeedback.selectionClick();
    setState(() => _qty.text = qty(next));
  }

  /// Runs [action], closes the sheet on success, shows the error otherwise.
  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final e = Expense(
      id: _initial?.id,
      name: _name.text.trim(),
      qty: double.parse(_qty.text.trim()),
      amount: double.parse(_amount.text.trim()),
      date: _date,
    );
    final emoji = context.style.emoji;
    _run(
      () => _initial == null
          ? widget.repo.add(e, widget.user.uid, widget.user.email)
          : widget.repo.update(e),
      _initial == null
          ? 'Added ${e.name} · ${taka(e.amount)} $emoji'
          : 'Saved ${e.name}',
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, size: 36),
        title: const Text('Delete expense?'),
        content: Text(
          '“${_initial!.name}” will be removed for both users.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 48),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _run(
        () => widget.repo.delete(_initial!.id!),
        'Deleted ${_initial!.name}',
      );
    }
  }

  String? _positiveNumber(String? v, String message) {
    final n = double.tryParse(v?.trim() ?? '');
    return (n == null || n <= 0) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = _initial;
    final style = context.style;
    final text = Theme.of(context).textTheme;
    final today = _today();
    final yesterday = today.subtract(const Duration(days: 1));
    final isOtherDay = _date != today && _date != yesterday;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                e == null ? 'New expense ${style.emoji}' : 'Edit expense',
                style: style.playful
                    ? style.greeting(30).copyWith(color: style.accent)
                    : text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (e != null && e.paid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Paid ${DateFormat.yMMMd().format(e.paidAt ?? e.date)}'
                        ' by ${shortName(e.paidBy)}',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              // Amount, big and front and center.
              TextFormField(
                controller: _amount,
                autofocus: e == null,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: style.accent,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixText: '৳ ',
                  prefixStyle: text.headlineMedium?.copyWith(
                    color: style.accent,
                    fontWeight: FontWeight.w700,
                  ),
                  helperText: 'Total taka for this line',
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                validator: (v) => _positiveNumber(v, 'Enter the amount'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What was it for?',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ActionChip(
                      avatar: Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: style.accent,
                      ),
                      label: Text(_recent[i]),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _name.text = _recent[i]);
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Qty stepper.
              Row(
                children: [
                  Text(
                    'Quantity',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => _stepQty(-1),
                    icon: const Icon(Icons.remove_rounded),
                    tooltip: 'Less',
                  ),
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      controller: _qty,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      validator: (v) => _positiveNumber(v, '!'),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _stepQty(1),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'More',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date: one tap for the usual cases.
              Text(
                'Date',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: _date == today,
                    onSelected: (_) => setState(() => _date = today),
                  ),
                  ChoiceChip(
                    label: const Text('Yesterday'),
                    selected: _date == yesterday,
                    onSelected: (_) => setState(() => _date = yesterday),
                  ),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: isOtherDay ? Colors.white : style.accent,
                    ),
                    label: Text(
                      isOtherDay
                          ? DateFormat.yMMMd().format(_date)
                          : 'Pick a date',
                    ),
                    selected: isOtherDay,
                    onSelected: (_) => _pickDate(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              GradientButton(
                label: e == null ? 'Save expense' : 'Save changes',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: _save,
              ),
              if (e != null && e.paid && widget.isAdmin) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => widget.repo.markUnpaid([e.id!]),
                          '${e.name} moved back to unpaid',
                        ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Mark unpaid'),
                ),
              ],
              if (e != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
