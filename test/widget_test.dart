import 'package:expense_tracker/config.dart';
import 'package:expense_tracker/format.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('taka and qty formatting', () {
    expect(taka(1250), '৳1,250');
    expect(taka(99.5), '৳99.5');
    expect(qty(2), '2');
    expect(qty(1.25), '1.25');
  });

  test('totalOf sums line totals', () {
    final d = DateTime(2026, 10, 28);
    final items = [
      Expense(name: 'Rice', qty: 5, amount: 400, date: d),
      Expense(name: 'Oil', qty: 1, amount: 180, date: d),
    ];
    expect(totalOf(items), 580);
  });

  test('admin check ignores case', () {
    expect(isAdminEmail('MahathirBishal@gmail.com'), isTrue);
    expect(isAdminEmail('someone@gmail.com'), isFalse);
    expect(isAdminEmail(null), isFalse);
  });

  test('CSV has header, escaped cells and a total row', () {
    final csv = expensesToCsv([
      Expense(
        name: 'Rice, "miniket"',
        qty: 5,
        amount: 400,
        date: DateTime(2026, 10, 28),
        paid: true,
        paidAt: DateTime(2026, 10, 29, 14, 5),
        paidBy: 'a@x.com',
        createdByEmail: 'b@x.com',
      ),
      Expense(name: 'Oil', qty: 1, amount: 180.5, date: DateTime(2026, 10, 25)),
    ]).split('\r\n');
    expect(csv.first, 'Name,Qty,Taka,Date,Status,Paid at,Paid by,Added by');
    expect(
      csv[1],
      '"Rice, ""miniket""",5,400,2026-10-28,Paid,2026-10-29 14:05,a@x.com,b@x.com',
    );
    expect(csv[2], 'Oil,1,180.5,2026-10-25,Unpaid,,,');
    expect(csv.last, 'TOTAL,,580.5,,,,,');
  });
}
