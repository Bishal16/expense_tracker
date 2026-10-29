import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../models/expense.dart';

final _date = DateFormat('yyyy-MM-dd');
final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

String _cell(Object? v) {
  final s = v?.toString() ?? '';
  return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// Builds a CSV that opens cleanly in Excel and Google Sheets.
String expensesToCsv(List<Expense> expenses) {
  final rows = [
    [
      'Name',
      'Qty',
      'Unit',
      'Taka',
      'Date',
      'Status',
      'Paid at',
      'Paid by',
      'Added by',
    ],
    for (final e in expenses)
      [
        e.name,
        e.qty == null ? '' : qty(e.qty!),
        e.unit ?? '',
        qty(e.amount),
        _date.format(e.date),
        e.paid ? 'Paid' : 'Unpaid',
        e.paidAt == null ? '' : _dateTime.format(e.paidAt!),
        e.paidBy ?? '',
        e.createdByEmail ?? '',
      ],
    ['TOTAL', '', '', qty(totalOf(expenses)), '', '', '', '', ''],
  ];
  return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
}

/// File-name friendly timestamp, e.g. 20261028_1718.
String fileStamp(DateTime t) => DateFormat('yyyyMMdd_HHmm').format(t);

/// Writes [expenses] to [name].csv and opens the share sheet.
Future<void> shareExpensesCsv(List<Expense> expenses, String name) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.csv');
  // The BOM makes Excel read Bangla text as UTF-8.
  await file.writeAsString('\uFEFF${expensesToCsv(expenses)}', encoding: utf8);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Expenses: $name',
    ),
  );
}
