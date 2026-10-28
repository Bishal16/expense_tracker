import 'package:intl/intl.dart';

final _taka = NumberFormat('#,##0.##');
final _qty = NumberFormat('0.##');

String taka(double v) => '৳${_taka.format(v)}';

String qty(double v) => _qty.format(v);

/// Short name for an email, e.g. "rahim" for rahim@gmail.com.
String shortName(String? email) =>
    (email == null || email.isEmpty) ? 'someone' : email.split('@').first;
