import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import 'home_screen.dart';

/// Lets the admin and approved users through; everyone else waits.
class AccessGate extends StatefulWidget {
  final User user;
  final AuthService auth;

  const AccessGate({super.key, required this.user, required this.auth});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  final _users = UserRepository();
  late final Stream<AppUser?> _me = _users.watchMe(widget.user.uid);
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    if (isAdminEmail(widget.user.email)) {
      return HomeScreen(user: widget.user, auth: widget.auth);
    }
    return StreamBuilder<AppUser?>(
      stream: _me,
      builder: (context, snap) {
        if (snap.hasError) {
          return _message(Icons.error_outline, 'Error', '${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final me = snap.data;
        if (me == null && !_requested) {
          _requested = true;
          _users.requestAccess(widget.user);
        }
        switch (me?.status) {
          case UserStatus.approved:
            return HomeScreen(user: widget.user, auth: widget.auth);
          case UserStatus.blocked:
            return _message(
              Icons.block,
              'Access blocked',
              'The admin has blocked ${widget.user.email}.',
            );
          case UserStatus.pending:
          case null:
            return _message(
              Icons.hourglass_top,
              'Waiting for approval',
              'Signed in as ${widget.user.email}.\n'
                  'Ask the admin to approve you in the admin panel. '
                  'This screen opens the app automatically once approved.',
            );
        }
      },
    );
  }

  Widget _message(IconData icon, String title, String body) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: widget.auth.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
