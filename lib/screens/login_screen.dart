import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/saved_accounts.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRegister ? 'Create account' : 'Sign in',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_saved.isNotEmpty && !_isRegister) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Saved accounts',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final a in _saved)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_circle),
                            title: Text(a.email),
                            subtitle: const Text('Tap to sign in'),
                            enabled: !_busy,
                            onTap: () => _signIn(a.email, a.password),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Forget ${a.email}',
                              onPressed: _busy ? null : () => _forget(a),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('or'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                    ] else
                      const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
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
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    CheckboxListTile(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? true),
                      title: const Text('Remember me on this phone'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegister ? 'Register' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? 'Already have an account? Sign in'
                            : 'No account? Register',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
