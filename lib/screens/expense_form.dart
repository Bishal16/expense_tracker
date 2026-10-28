import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';

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
    showDragHandle: true,
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
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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

  /// Runs [action], closes the sheet on success, shows the error otherwise.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    _run(
      () => _initial == null
          ? widget.repo.add(e, widget.user.uid, widget.user.email)
          : widget.repo.update(e),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"${_initial!.name}" will be removed for both users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) _run(() => widget.repo.delete(_initial!.id!));
  }

  String? _positiveNumber(String? v, String message) {
    final n = double.tryParse(v?.trim() ?? '');
    return (n == null || n <= 0) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = _initial;
    final isToday = _date == _today();
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
                e == null ? 'Add expense' : 'Edit expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (e != null && e.paid)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Paid ${DateFormat.yMMMd().format(e.paidAt ?? e.date)}'
                    ' by ${shortName(e.paidBy)}',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: e == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _positiveNumber(v, 'Invalid'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Taka (total)',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _positiveNumber(v, 'Enter taka'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  isToday
                      ? 'Today (${DateFormat.yMMMd().format(_date)})'
                      : DateFormat.yMMMd().format(_date),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
              if (e != null && e.paid && widget.isAdmin)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => widget.repo.markUnpaid([e.id!])),
                  icon: const Icon(Icons.undo),
                  label: const Text('Mark unpaid'),
                ),
              if (e != null)
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
