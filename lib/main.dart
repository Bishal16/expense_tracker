import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/theme_prefs.dart';
import 'screens/access_gate.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/prefs_repository.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ExpenseTrackerApp(auth: AuthService()));
}

class ExpenseTrackerApp extends StatefulWidget {
  final AuthService auth;

  const ExpenseTrackerApp({super.key, required this.auth});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  final _prefsRepo = PrefsRepository();
  late final Stream<User?> _auth = widget.auth.authStateChanges();
  String? _prefsUid;
  Stream<ThemePrefs?> _prefs = Stream.value(null);

  /// One prefs subscription per signed-in user.
  Stream<ThemePrefs?> _prefsFor(User? user) {
    if (user?.uid != _prefsUid) {
      _prefsUid = user?.uid;
      _prefs = user == null
          ? Stream.value(null)
          : _prefsRepo.watch(user.uid, user.email);
    }
    return _prefs;
  }

  @override
  Widget build(BuildContext context) {
    // The whole app, including dialogs and pushed pages, takes the signed-in
    // user's style, and restyles live when they change it in settings.
    return StreamBuilder<User?>(
      stream: _auth,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final user = snap.data;
        return StreamBuilder<ThemePrefs?>(
          stream: _prefsFor(user),
          builder: (context, prefsSnap) {
            final style = AppStyle.resolve(user?.email, prefsSnap.data);
            return MaterialApp(
              title: 'Expense Tracker',
              debugShowCheckedModeBanner: false,
              theme: style.theme,
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(
                      mq.textScaler.scale(1) * style.prefs.textScale,
                    ),
                  ),
                  child: child!,
                );
              },
              home: waiting
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : user == null
                  ? LoginScreen(auth: widget.auth)
                  : AccessGate(
                      key: ValueKey(user.uid),
                      user: user,
                      auth: widget.auth,
                    ),
            );
          },
        );
      },
    );
  }
}
