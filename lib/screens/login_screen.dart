import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../format.dart';
import '../services/auth_service.dart';
import '../services/saved_accounts.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;

  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _savedStore = SavedAccounts();
  List<SavedAccount> _saved = [];
  bool _isRegister = false;
  bool _remember = true;
  bool _showPassword = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _savedStore.load().then((s) {
      if (mounted) setState(() => _saved = s);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _signIn(_email.text.trim(), _password.text, register: _isRegister);
  }

  Future<void> _signIn(
    String email,
    String password, {
    bool register = false,
  }) async {
    setState(() => _busy = true);
    try {
      if (register) {
        await widget.auth.register(email, password);
      } else {
        await widget.auth.signIn(email, password);
      }
      // Lets Google / Samsung Pass offer to save the login.
      TextInput.finishAutofillContext();
      if (_remember) {
        await _savedStore.save(email, password);
      } else {
        await _savedStore.remove(email);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // Put the details in the form so a changed password can be fixed.
        _email.text = email;
        _password.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget(SavedAccount a) async {
    await _savedStore.remove(a.email);
    final s = await _savedStore.load();
    if (mounted) setState(() => _saved = s);
  }

  Widget _savedCard(SavedAccount a) {
    // Each saved account wears its owner's colors.
    final look = AppStyle.forEmail(a.email);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: look.headerGradient),
          child: InkWell(
            onTap: _busy ? null : () => _signIn(a.email, a.password),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Icon(look.motif, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdminEmail(a.email)
                              ? 'Admin'
                              : '${friendlyName(a.email)} ${look.emoji}',
                          style: look
                              .greeting(18)
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          a.email,
                          style: text.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.login_rounded, color: Colors.white),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Forget ${a.email}',
                    onPressed: _busy ? null : () => _forget(a),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: style.headerGradient),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: 40,
                child: Icon(
                  Icons.local_florist_rounded,
                  size: 220,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                left: -50,
                bottom: 60,
                child: Icon(
                  Icons.insights_rounded,
                  size: 200,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _isRegister ? 'Create account' : 'Welcome back',
                              textAlign: TextAlign.center,
                              style: style
                                  .greeting(30)
                                  .copyWith(color: Colors.white),
                            ),
                            Text(
                              'Track every taka, together ✨',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_saved.isNotEmpty && !_isRegister) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Tap to sign in',
                                  style: text.labelLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              for (final a in _saved) _savedCard(a),
                              const SizedBox(height: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 30,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_saved.isNotEmpty && !_isRegister)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        'Or use another account',
                                        style: text.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.username,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.mail_outline_rounded,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                        ? 'Enter a valid email'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: !_showPassword,
                                    autofillHints: [
                                      _isRegister
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                        ),
                                        tooltip: _showPassword
                                            ? 'Hide password'
                                            : 'Show password',
                                        onPressed: () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.length < 6)
                                        ? 'At least 6 characters'
                                        : null,
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                  CheckboxListTile(
                                    value: _remember,
                                    onChanged: (v) =>
                                        setState(() => _remember = v ?? true),
                                    title: const Text(
                                      'Remember me on this phone',
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  GradientButton(
                                    label: _isRegister ? 'Register' : 'Sign in',
                                    icon: _isRegister
                                        ? Icons.person_add_alt_1_rounded
                                        : Icons.arrow_forward_rounded,
                                    busy: _busy,
                                    onPressed: _submit,
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _isRegister = !_isRegister,
                                          ),
                                    child: Text(
                                      _isRegister
                                          ? 'Already have an account? Sign in'
                                          : 'No account? Register',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
