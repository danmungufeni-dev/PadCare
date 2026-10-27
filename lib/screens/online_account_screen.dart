import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/padcare_backend.dart';

class OnlineAccountScreen extends StatefulWidget {
  const OnlineAccountScreen({super.key});

  @override
  State<OnlineAccountScreen> createState() => _OnlineAccountScreenState();
}

class _OnlineAccountScreenState extends State<OnlineAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password with at least 6 characters.';
        case 'email-already-in-use':
          return 'An account already uses this email. Try signing in.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password was not recognised.';
        case 'network-request-failed':
          return 'Network connection failed. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a little before trying again.';
      }
    }
    return 'We could not complete that action. Check your connection and Firebase setup, then try again.';
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!PadCareBackend.isConfigured) {
      setState(() => _error =
          'Online accounts are not enabled yet. The project owner must configure Firebase for Android, iOS, or web first. Your local preview still works.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_creatingAccount) {
        await PadCareBackend.createParentAccount(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await PadCareBackend.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PadCare online account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF35B9B4), Color(0xFFA5EAC5)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_done_outlined, size: 34, color: Color(0xFF116B78)),
                  SizedBox(height: 12),
                  Text(
                    'Connect with PadCare',
                    style: TextStyle(
                      color: Color(0xFF142426),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'An online account can sync your pickup requests across devices. Requests still avoid asking for a girl’s name, age, or class.',
                    style: TextStyle(color: Color(0xFF21494D), height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Sign in'), icon: Icon(Icons.login_rounded)),
                ButtonSegment<bool>(value: true, label: Text('Create account'), icon: Icon(Icons.person_add_alt_1_rounded)),
              ],
              selected: {_creatingAccount},
              onSelectionChanged: _busy
                  ? null
                  : (selection) => setState(() {
                        _creatingAccount = selection.first;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_creatingAccount) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name (optional)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autofillHints: _creatingAccount
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (_creatingAccount && password.length < 6) {
                        return 'Use at least 6 characters.';
                      }
                      if (password.isEmpty) return 'Enter your password.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD6A5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFF79430B), height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF116B78),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_creatingAccount ? 'Create parent account' : 'Sign in securely'),
            ),
            const SizedBox(height: 14),
            const Text(
              'School staff accounts must be approved and provisioned by a trusted PadCare administrator. Creating a parent account does not grant school-staff access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF637A83), fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
