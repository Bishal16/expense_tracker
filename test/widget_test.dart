import 'package:expense_tracker/config.dart';
import 'package:expense_tracker/format.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/theme_prefs.dart';
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
        unit: 'kg',
        amount: 400,
        date: DateTime(2026, 10, 28),
        paid: true,
        paidAt: DateTime(2026, 10, 29, 14, 5),
        paidBy: 'a@x.com',
        createdByEmail: 'b@x.com',
      ),
      Expense(name: 'Oil', amount: 180.5, date: DateTime(2026, 10, 25)),
    ]).split('\r\n');
    expect(
      csv.first,
      'Name,Qty,Unit,Taka,Date,Status,Paid at,Paid by,Added by',
    );
    expect(
      csv[1],
      '"Rice, ""miniket""",5,kg,400,2026-10-28,Paid,2026-10-29 14:05,a@x.com,b@x.com',
    );
    expect(csv[2], 'Oil,,,180.5,2026-10-25,Unpaid,,,');
    expect(csv.last, 'TOTAL,,,580.5,,,,,');
  });

  test('friendly names and day labels', () {
    expect(friendlyName('user1.faria@gmail.com'), 'Faria');
    expect(friendlyName('rahim@gmail.com'), 'Rahim');
    expect(friendlyName(null), 'Someone');
    final now = DateTime(2026, 10, 28, 15);
    expect(dayLabel(DateTime(2026, 10, 28, 9), now), 'Today');
    expect(dayLabel(DateTime(2026, 10, 27, 23), now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 10, 25), now), 'Sun, Oct 25');
    expect(dayLabel(DateTime(2025, 10, 25), now), 'Sat, Oct 25, 2025');
    expect(timeGreeting(DateTime(2026, 1, 1, 9)), 'Good morning');
    expect(timeGreeting(DateTime(2026, 1, 1, 20)), 'Good evening');
  });

  test('qtyLabel combines optional qty and unit', () {
    final d = DateTime(2026, 10, 29);
    expect(Expense(name: 'a', amount: 1, date: d).qtyLabel, isNull);
    expect(Expense(name: 'a', amount: 1, date: d, qty: 2).qtyLabel, '2');
    expect(
      Expense(name: 'a', amount: 1, date: d, qty: 1.5, unit: 'kg').qtyLabel,
      '1.5 kg',
    );
    expect(Expense(name: 'a', amount: 1, date: d, unit: 'pcs').qtyLabel, 'pcs');
  });

  test('ThemePrefs round-trips and falls back on bad values', () {
    final base = ThemePrefs.defaults(admin: false);
    final custom = base.copyWith(
      palette: 'mint',
      greetingFont: 'Pacifico',
      radius: 32,
      displayName: 'Fari',
    );
    final back = ThemePrefs.fromMap(custom.toMap(), base);
    expect(back.palette, 'mint');
    expect(back.greetingFont, 'Pacifico');
    expect(back.radius, 32);
    expect(back.displayName, 'Fari');

    final junk = ThemePrefs.fromMap({
      'palette': 'nope',
      'bodyFont': 'Comic Sans',
      'motif': 'dragon',
      'textScale': 9,
      'displayName': '  ',
    }, base);
    expect(junk.palette, base.palette);
    expect(junk.bodyFont, base.bodyFont);
    expect(junk.motif, base.motif);
    expect(junk.textScale, 1.3);
    expect(junk.displayName, isNull);
    expect(ThemePrefs.defaults(admin: true).palette, 'midnight');
  });
}
