import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/access_gate.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ExpenseTrackerApp(auth: AuthService()));
}

class ExpenseTrackerApp extends StatelessWidget {
  final AuthService auth;

  const ExpenseTrackerApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    // The whole app, including dialogs and pushed pages, takes the signed-in
    // user's style.
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final user = snap.data;
        return MaterialApp(
          title: 'Expense Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppStyle.forEmail(user?.email).theme,
          home: waiting
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : user == null
              ? LoginScreen(auth: auth)
              : AccessGate(key: ValueKey(user.uid), user: user, auth: auth),
        );
      },
    );
  }
}
