import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

final _taka = NumberFormat('#,##0.##');
final _qty = NumberFormat('0.##');

String taka(double v) => '৳${_taka.format(v)}';

String qty(double v) => _qty.format(v);

/// Short name for an email, e.g. "rahim" for rahim@gmail.com.
String shortName(String? email) =>
    (email == null || email.isEmpty) ? 'someone' : email.split('@').first;

/// Friendly first name from an email, e.g. "Faria" for user1.faria@gmail.com.
String friendlyName(String? email) {
  final parts = shortName(email)
      .split(RegExp(r'[^A-Za-z]+'))
      .where((p) => p.length > 1)
      .toList();
  if (parts.isEmpty) return 'there';
  final name = parts.last;
  return name[0].toUpperCase() + name.substring(1).toLowerCase();
}

/// "Good morning" / "Good afternoon" / "Good evening".
String timeGreeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Today", "Yesterday" or e.g. "Sat, Oct 25".
String dayLabel(DateTime d, [DateTime? now]) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final diff = today.difference(DateUtils.dateOnly(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, MMM d${d.year == today.year ? '' : ', y'}').format(d);
}
