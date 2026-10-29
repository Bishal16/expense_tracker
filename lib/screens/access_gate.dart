import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme.dart';
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
              'Almost there ${context.style.emoji}',
              'Signed in as ${widget.user.email}.\n'
                  'Ask the admin to approve you in the admin panel. '
                  'This screen opens the app automatically once approved.',
            );
        }
      },
    );
  }

  Widget _message(IconData icon, String title, String body) {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: style.headerGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: style.headerGradient,
                        ),
                        child: Icon(icon, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: style.greeting(26).copyWith(color: style.accent),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: widget.auth.signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
