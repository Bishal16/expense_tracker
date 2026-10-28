import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final String email;
  final String password;

  const SavedAccount(this.email, this.password);
}

/// "Remember me" logins, encrypted on the device (Android Keystore / iOS
/// Keychain). Never leaves the phone.
class SavedAccounts {
  static const _key = 'saved_accounts';
  final _storage = const FlutterSecureStorage();

  Future<List<SavedAccount>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return [];
      return [
        for (final a in jsonDecode(raw) as List)
          SavedAccount(a['email'] as String, a['password'] as String),
      ];
    } catch (_) {
      // Unreadable storage (e.g. after a backup restore): start fresh.
      return [];
    }
  }

  Future<void> save(String email, String password) async {
    final accounts = (await load()).where((a) => a.email != email).toList()
      ..insert(0, SavedAccount(email, password));
    await _write(accounts);
  }

  Future<void> remove(String email) async =>
      _write((await load()).where((a) => a.email != email).toList());

  Future<void> _write(List<SavedAccount> accounts) => _storage.write(
    key: _key,
    value: jsonEncode([
      for (final a in accounts) {'email': a.email, 'password': a.password},
    ]),
  );
}
