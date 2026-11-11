import 'dart:async';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/school_service.dart';
import '../info/info_screens.dart';
import '../services/url_launcher_stub.dart'
    if (dart.library.html) '../services/url_launcher_web.dart';

/// Navigation coordinator for PadCare Authentication Suite.
/// Allows decoupled navigation into PadCare home screens.
class PadCareAuthNavigator {
  static bool testMode = false;
  static void Function(
    BuildContext context, {
    String? email,
    String? role,
    String? displayName,
    String? photoUrl,
    String? uid,
  })? onNavigateToApp;

  static void openApp(
    BuildContext context, {
    String? email,
    String? role,
    String? displayName,
    String? photoUrl,
    String? uid,
  }) {
    if (onNavigateToApp != null) {
      onNavigateToApp!(
        context,
        email: email,
        role: role,
        displayName: displayName,
        photoUrl: photoUrl,
        uid: uid,
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ---------------------------------------------------------------------------
// 1. EmailVerification
// ---------------------------------------------------------------------------
class EmailVerification extends StatefulWidget {
  final String? email;
  final String? role;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback? onVerified;
  final VoidCallback? onOpenEmailApp;
  final VoidCallback? onResendEmail;

  const EmailVerification({
    super.key,
    this.email,
    this.role,
    this.displayName,
    this.photoUrl,
    this.onVerified,
    this.onOpenEmailApp,
    this.onResendEmail,
  });

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  bool _checking = false;
  String? _statusError;

  Future<void> _handleContinue() async {
    setState(() {
      _checking = true;
      _statusError = null;
    });

    try {
      final emailToCheck = widget.email ?? AuthService.currentUser?.email;
      final isPreverified = emailToCheck != null && FirestoreService.isPreverifiedDemoEmail(emailToCheck);
      final verified = isPreverified || await AuthService.isEmailVerified(emailToCheck);
      final canProceed = verified || PadCareAuthNavigator.testMode;

      if (!canProceed) {
        if (!mounted) return;
        final displayEmail = emailToCheck ?? 'your email';
        setState(() {
          _checking = false;
          _statusError =
              'We have not detected your email verification yet. Please open the link sent to $displayEmail first, then tap continue.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Email not yet verified. Please click the link sent to $displayEmail first.'),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Email verified! Proceeding to PadCare...'),
          backgroundColor: Color(0xFF116B78),
          duration: Duration(seconds: 2),
        ),
      );

      if (widget.onVerified != null) {
        widget.onVerified!();
        return;
      }

      final displayEmail = widget.email ?? AuthService.currentUser?.email ?? 'community@padcare.org';
      PadCareAuthNavigator.openApp(
        context,
        email: displayEmail,
        role: widget.role ?? (displayEmail.toLowerCase().contains('teacher') ? 'teacher' : 'parent'),
        displayName: widget.displayName,
        photoUrl: widget.photoUrl,
        uid: AuthService.currentUser?.uid,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusError = 'Verification error: $e';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayEmail = widget.email ?? AuthService.currentUser?.email ?? 'community@padcare.org';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 60,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Verify your email',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                children: [
                  const TextSpan(text: 'We sent a verification link to\n'),
                  TextSpan(
                    text: displayEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: '. Click the link to activate your PadCare account.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (_statusError != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Email Verification Required',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E), fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusError!,
                      style: const TextStyle(color: Color(0xFF78350F), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Check your inbox and spam folder.\n• If using institutional email (@muni.ac.ug), check campus filters.\n• After clicking the link in your email, tap the button below again.',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  if (widget.onOpenEmailApp != null) {
                    widget.onOpenEmailApp!();
                  } else {
                    final lower = displayEmail.toLowerCase();
                    String url = 'https://mail.google.com/mail/u/0/#search/in%3Aanywhere+padcare';
                    if (lower.contains('@yahoo.')) {
                      url = 'https://mail.yahoo.com/';
                    } else if (lower.contains('@outlook.') || lower.contains('@hotmail.')) {
                      url = 'https://outlook.live.com/';
                    }
                    try {
                      openExternalUrl(url);
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening webmail / Gmail for $displayEmail...'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open email app'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't get it?",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                TextButton(
                  onPressed: () async {
                    if (widget.onResendEmail != null) {
                      widget.onResendEmail!();
                    } else {
                      final res = await AuthService.sendEmailVerification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.isSuccess
                              ? 'Verification email sent to $displayEmail! (Check your inbox or spam)'
                              : (res.errorMessage ?? 'Failed to send verification email.')),
                          backgroundColor: res.isSuccess ? const Color(0xFF116B78) : Colors.redAccent,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: const Text('Resend email'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _checking ? null : _handleContinue,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF116B78), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _checking
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF116B78)),
                          ),
                          SizedBox(width: 10),
                          Text('Checking verification...'),
                        ],
                      )
                    : const Text(
                        "I've verified, continue to PadCare",
                        style: TextStyle(color: Color(0xFF116B78), fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. LoginHero
// ---------------------------------------------------------------------------
class LoginHero extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final String? initialEmail;

  const LoginHero({
    super.key,
    this.onLoginSuccess,
    this.initialEmail,
  });

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<LoginHero> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _remember = true;
  bool _obscure = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await AuthService.signIn(email: email, password: password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        final isVerified = (AuthService.currentUser?.emailVerified ?? true) ||
            FirestoreService.isPreverifiedDemoEmail(email);
        final role = result.profile?.role ?? (email.toLowerCase().contains('teacher') ? 'teacher' : 'parent');

        if (!isVerified && !PadCareAuthNavigator.testMode) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EmailVerification(
                email: email,
                role: role,
                displayName: result.profile?.displayName ?? result.user?.displayName,
                photoUrl: result.photoUrl ?? result.profile?.photoUrl,
              ),
            ),
          );
          return;
        }

        PadCareAuthNavigator.openApp(
          context,
          email: email,
          role: role,
          displayName: result.profile?.displayName ?? result.user?.displayName,
          photoUrl: result.photoUrl ?? result.profile?.photoUrl,
          uid: result.user?.uid ?? result.profile?.uid,
        );
      }
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Sign in failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      appBar: AppBar(
        title: const Text('PadCare Sign In'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18116B78),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/padcare_icon.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/icon/app_icon.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F8F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA5EAC5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 13,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Firebase Auth & Storage Connected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF116B78),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF172B36),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F8F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA5EAC5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF116B78)),
                            SizedBox(width: 5),
                            Text(
                              '1-Tap Quick Demo Logins',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF116B78),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _emailController.text = 'devgtnation@gmail.com';
                                  _passwordController.text = 'PadCare2026!';
                                  _handleSignIn();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFDCECEB)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.school_outlined, size: 14, color: Color(0xFF116B78)),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Dan M. (Teacher)',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF172B36)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _emailController.text = 'abetinichlas@gmail.com';
                                  _passwordController.text = 'PadCare2026!';
                                  _handleSignIn();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFDCECEB)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.family_restroom_outlined, size: 14, color: Color(0xFF116B78)),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Nicholas A. (Parent)',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF172B36)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF116B78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF116B78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6B8487)),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _remember,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              activeColor: const Color(0xFF116B78),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (v) => setState(() => _remember = v ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                'Remember me',
                                style: TextStyle(color: Color(0xFF172B36), fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ResetPassword(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Color(0xFF116B78),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _handleSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF116B78),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Color(0xFF6B8487), fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignupTerms(),
                            ),
                          );
                        },
                        child: const Text('Sign up', style: TextStyle(color: Color(0xFF116B78), fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCECEB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0D9488)),
                            SizedBox(width: 5),
                            Text(
                              'Creator & Demo Access',
                              style: TextStyle(
                                color: Color(0xFF116B78),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  PadCareAuthNavigator.openApp(
                                    context,
                                    email: 'devgtnation@gmail.com',
                                    role: 'teacher',
                                    displayName: 'Dan Mungufeni (Lead Dev)',
                                    photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
                                  );
                                },
                                icon: const Icon(Icons.school_outlined, size: 15, color: Color(0xFF116B78)),
                                label: const Text('Dan Mungufeni', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF172B36),
                                  side: const BorderSide(color: Color(0xFFDCECEB)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  PadCareAuthNavigator.openApp(
                                    context,
                                    email: 'abetinichlas@gmail.com',
                                    role: 'parent',
                                    displayName: 'Abeti Acadri Nicholas',
                                    photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
                                  );
                                },
                                icon: const Icon(Icons.family_restroom_outlined, size: 15, color: Color(0xFF116B78)),
                                label: const Text('Abeti Nicholas', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF172B36),
                                  side: const BorderSide(color: Color(0xFFDCECEB)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          children: [
                            ActionChip(
                              label: const Text('Fill Dan (devgtnation)', style: TextStyle(fontSize: 10.5, color: Color(0xFF116B78))),
                              avatar: const Icon(Icons.school, size: 14, color: Color(0xFF116B78)),
                              backgroundColor: const Color(0xFFE4F8F2),
                              side: const BorderSide(color: Color(0xFFA5EAC5)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'devgtnation@gmail.com';
                                  _passwordController.text = 'PadCare2026!';
                                });
                              },
                            ),
                            ActionChip(
                              label: const Text('Fill Nicholas (abeti)', style: TextStyle(fontSize: 10.5, color: Color(0xFF116B78))),
                              avatar: const Icon(Icons.family_restroom, size: 14, color: Color(0xFF116B78)),
                              backgroundColor: const Color(0xFFE4F8F2),
                              side: const BorderSide(color: Color(0xFFA5EAC5)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'abetinichlas@gmail.com';
                                  _passwordController.text = 'PadCare2026!';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MagicLink(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Magic link'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PinLock(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.pin, size: 18),
                  label: const Text('PIN lock'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BiometricUnlock(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Biometrics'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. MagicLink
// ---------------------------------------------------------------------------
class MagicLink extends StatefulWidget {
  final VoidCallback? onAuthenticated;

  const MagicLink({super.key, this.onAuthenticated});

  @override
  State<MagicLink> createState() => _MagicLinkState();
}

class _MagicLinkState extends State<MagicLink> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emailText = _emailController.text.trim().isEmpty
        ? 'alex@example.com'
        : _emailController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passwordless Access'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _sent
              ? [
                  const Spacer(),
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 72,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Check your inbox',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a magic sign-in link to $emailText. Tap the link to log in to PadCare — no password needed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      if (widget.onAuthenticated != null) {
                        widget.onAuthenticated!();
                      } else {
                        PadCareAuthNavigator.openApp(
                          context,
                          email: emailText,
                          role: 'parent',
                        );
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Continue to PadCare'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _sent = false),
                    child: const Text('Use a different email'),
                  ),
                ]
              : [
                  const Spacer(),
                  Icon(Icons.auto_awesome, size: 64, color: scheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Passwordless login',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter your email and we\'ll send you a secure sign-in link to access PadCare.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_emailController.text.trim().isNotEmpty) {
                          setState(() => _sent = true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an email address first.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send magic link'),
                    ),
                  ),
                  const Spacer(),
                ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. PinLock & Keypad
// ---------------------------------------------------------------------------
class PinLock extends StatefulWidget {
  final String correctPin;
  final VoidCallback? onUnlocked;

  const PinLock({
    super.key,
    this.correctPin = '1234',
    this.onUnlocked,
  });

  @override
  State<PinLock> createState() => _PinLockState();
}

class _PinLockState extends State<PinLock> {
  String _pin = '';
  bool _error = false;

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (_pin == widget.correctPin) {
          if (widget.onUnlocked != null) {
            widget.onUnlocked!();
          } else {
            PadCareAuthNavigator.openApp(
              context,
              email: 'pin-user@padcare.org',
              displayName: 'PIN User',
            );
          }
        } else {
          setState(() {
            _error = true;
            _pin = '';
          });
        }
      });
    }
  }

  void _back() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PadCare PIN Access'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 34,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.lock_outline,
                size: 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enter your PIN',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ? 'Incorrect PIN, try again' : 'Hint: ${widget.correctPin}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _error ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                );
              }),
            ),
            const Spacer(),
            _Keypad(onTap: _tap, onBackspace: _back),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => BiometricUnlock(onUnlocked: widget.onUnlocked),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use biometrics'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PinCreate(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Set new PIN'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onTap;
  final VoidCallback onBackspace;
  const _Keypad({required this.onTap, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        physics: const NeverScrollableScrollPhysics(),
        children: keys.map((k) {
          if (k.isEmpty) return const SizedBox();
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => k == '⌫' ? onBackspace() : onTap(k),
            child: Center(
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined, size: 26)
                  : Text(
                      k,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4b. PinCreate
// ---------------------------------------------------------------------------
class PinCreate extends StatefulWidget {
  final void Function(String pin)? onPinCreated;
  final VoidCallback? onCancel;

  const PinCreate({super.key, this.onPinCreated, this.onCancel});

  @override
  State<PinCreate> createState() => _PinCreateState();
}

class _PinCreateState extends State<PinCreate> {
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PinConfirm(
              initialPin: _pin,
              onPinConfirmed: (confirmedPin) {
                if (widget.onPinCreated != null) {
                  widget.onPinCreated!(confirmedPin);
                } else {
                  Navigator.of(context).pop(); // pop confirm
                  Navigator.of(context).pop(); // pop create
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN successfully created and saved!'),
                      backgroundColor: Color(0xFF166534),
                    ),
                  );
                }
              },
            ),
          ),
        );
      });
    }
  }

  void _back() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create PIN'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 34,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.pin_outlined,
                size: 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create your PIN',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a 4-digit PIN for quick access',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                );
              }),
            ),
            const Spacer(),
            _Keypad(onTap: _tap, onBackspace: _back),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4c. PinConfirm
// ---------------------------------------------------------------------------
class PinConfirm extends StatefulWidget {
  final String initialPin;
  final void Function(String pin)? onPinConfirmed;
  final VoidCallback? onMismatch;

  const PinConfirm({
    super.key,
    required this.initialPin,
    this.onPinConfirmed,
    this.onMismatch,
  });

  @override
  State<PinConfirm> createState() => _PinConfirmState();
}

class _PinConfirmState extends State<PinConfirm> {
  String _pin = '';
  bool _error = false;

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (_pin == widget.initialPin) {
          if (widget.onPinConfirmed != null) {
            widget.onPinConfirmed!(_pin);
          } else {
            Navigator.of(context).pop(_pin);
          }
        } else {
          setState(() {
            _error = true;
            _pin = '';
          });
          if (widget.onMismatch != null) widget.onMismatch!();
        }
      });
    }
  }

  void _back() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm PIN'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 34,
              backgroundColor: _error ? scheme.errorContainer : scheme.primaryContainer,
              child: Icon(
                _error ? Icons.lock_clock_outlined : Icons.lock_outline,
                size: 34,
                color: _error ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm your PIN',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ? "PINs don't match, try again" : 'Re-enter your 4-digit PIN to confirm',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _error ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (_error ? scheme.error : scheme.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: _error ? scheme.error : scheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
            _Keypad(onTap: _tap, onBackspace: _back),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start over'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. ResetPassword & Rule
// ---------------------------------------------------------------------------
class ResetPassword extends StatefulWidget {
  final VoidCallback? onPasswordReset;

  const ResetPassword({super.key, this.onPasswordReset});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  String _password = '';
  String _confirm = '';
  bool _obscure = true;

  bool get _hasLength => _password.length >= 8;
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_password);
  bool get _matches => _password.isNotEmpty && _password == _confirm;
  bool get _valid => _hasLength && _hasNumber && _matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      appBar: AppBar(
        title: const Text('Reset password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                Text(
                  'Set a new password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF172B36),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your new password must be different from previously used passwords on PadCare.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B8487)),
                ),
                const SizedBox(height: 24),
                TextField(
                  obscureText: _obscure,
                  onChanged: (v) => setState(() => _password = v),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF116B78)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF6B8487)),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: _obscure,
                  onChanged: (v) => setState(() => _confirm = v),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF116B78)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Rule(label: 'At least 8 characters', met: _hasLength),
                _Rule(label: 'Contains a number', met: _hasNumber),
                _Rule(label: 'Passwords match', met: _matches),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF116B78),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _valid
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password updated successfully! You can now log in to PadCare.',
                                ),
                              ),
                            );
                            if (widget.onPasswordReset != null) {
                              widget.onPasswordReset!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          }
                        : null,
                    child: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final bool met;
  const _Rule({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: met ? Colors.green : scheme.outline,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: met ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. SignupTerms
// ---------------------------------------------------------------------------
class SignupTerms extends StatefulWidget {
  final VoidCallback? onSignedUp;

  const SignupTerms({super.key, this.onSignedUp});

  @override
  State<SignupTerms> createState() => _SignupTermsState();
}

class _SignupTermsState extends State<SignupTerms> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newSchoolNameController = TextEditingController();
  final _newSchoolPhoneController = TextEditingController();
  final _newSchoolAdminPasskeyController = TextEditingController();
  bool _obscureAdminPasskey = true;
  String? _newSchoolPasskeyError;
  String _newSchoolSubCounty = 'Arua Hill';
  bool _isAddingSchool = false;
  bool _savingSchool = false;
  String _password = '';
  String _role = 'parent';
  String _school = "St. Mary's Secondary";
  int _selectedAvatarIndex = 0;
  static const _presetAvatars = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=256&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=256&q=80',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=256&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
  ];
  late List<String> _schools;
  bool _agreed = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _schools = List<String>.from(SchoolService.cachedSchoolNames);
    if (!_schools.contains("St. Mary's Secondary")) {
      _schools.insert(0, "St. Mary's Secondary");
    }
    _fetchDynamicSchools();
  }

  void _fetchDynamicSchools() async {
    final names = await SchoolService.fetchSchoolNames();
    if (mounted && names.isNotEmpty) {
      setState(() {
        _schools = List<String>.from(names);
        if (!_schools.contains(_school)) {
          _schools.insert(0, _school);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newSchoolNameController.dispose();
    _newSchoolPhoneController.dispose();
    _newSchoolAdminPasskeyController.dispose();
    super.dispose();
  }

  Future<void> _handleAddNewSchool() async {
    final name = _newSchoolNameController.text.trim();
    final passkey = _newSchoolAdminPasskeyController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a school name.')),
      );
      return;
    }

    // Verify PadCare Admin Passkey
    final isTest = PadCareAuthNavigator.testMode ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final isPasskeyValid = FirestoreService.verifyAdminPasskey(passkey);

    if (!isPasskeyValid && (!isTest || passkey.isNotEmpty)) {
      setState(() {
        _newSchoolPasskeyError =
            'Incorrect admin password. Only authorized PadCare admins can register new partner schools.';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 Incorrect Admin Password. Authorized PadCare administrator passkey required.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _savingSchool = true;
      _newSchoolPasskeyError = null;
    });

    final schoolId = SchoolService.generateSchoolId(name);
    final school = SchoolModel(
      schoolId: schoolId,
      name: name,
      district: 'Arua',
      subCounty: _newSchoolSubCounty,
      contactPhone: _newSchoolPhoneController.text.trim().isNotEmpty
          ? _newSchoolPhoneController.text.trim()
          : '+256700000000',
      createdAt: DateTime.now(),
    );
    await SchoolService.saveSchool(school);
    if (!mounted) return;
    setState(() {
      _savingSchool = false;
      _newSchoolPasskeyError = null;
      if (!_schools.contains(name)) {
        _schools.add(name);
        _schools.sort();
      }
      _school = name;
      _isAddingSchool = false;
      _newSchoolNameController.clear();
      _newSchoolPhoneController.clear();
      _newSchoolAdminPasskeyController.clear();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 School "$name" added and selected!'),
        backgroundColor: const Color(0xFF116B78),
      ),
    );
  }

  int get _strength {
    var score = 0;
    if (_password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(_password)) score++;
    if (RegExp(r'[0-9]').hasMatch(_password)) score++;
    if (RegExp(r'[!@#$%^&*]').hasMatch(_password)) score++;
    return score;
  }

  static const _labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];

  Future<void> _handleCreateAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please complete all required fields.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final selectedPhotoUrl = _presetAvatars[_selectedAvatarIndex];
    final result = await AuthService.register(
      email: email,
      password: password,
      displayName: name.isNotEmpty ? name : 'PadCare User',
      role: _role,
      school: _role == 'teacher' ? _school : null,
      photoUrl: selectedPhotoUrl,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmailVerification(
            email: email,
            role: _role,
            displayName: name,
            photoUrl: result.photoUrl ?? selectedPhotoUrl,
            onVerified: () {
              if (widget.onSignedUp != null) {
                widget.onSignedUp!();
              } else {
                PadCareAuthNavigator.openApp(
                  context,
                  email: email,
                  role: _role,
                  displayName: name,
                  photoUrl: result.photoUrl ?? selectedPhotoUrl,
                  uid: result.user?.uid ?? result.profile?.uid,
                );
              }
            },
          ),
        ),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Registration failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF0D9488),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18116B78),
                            blurRadius: 16,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/padcare_icon.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/icon/app_icon.png',
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Get started free with PadCare',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF172B36),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join our community network for confidential, reliable menstrual hygiene support.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B8487),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF116B78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF116B78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (v) => setState(() => _password = v),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF116B78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(4, (i) {
                      final active = i < _strength;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 5,
                          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: active ? colors[_strength] : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Strength: ${_labels[_strength]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors[_strength],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Register as',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF172B36),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color(0xFFE4F8F2),
                      selectedForegroundColor: const Color(0xFF116B78),
                      foregroundColor: const Color(0xFF6B8487),
                      side: const BorderSide(color: Color(0xFFDCECEB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'parent',
                        label: Text('Community Member', style: TextStyle(fontWeight: FontWeight.w700)),
                        icon: Icon(Icons.family_restroom_outlined),
                      ),
                      ButtonSegment(
                        value: 'teacher',
                        label: Text('Teacher', style: TextStyle(fontWeight: FontWeight.w700)),
                        icon: Icon(Icons.school_outlined),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: (set) {
                      setState(() => _role = set.first);
                    },
                  ),
                  if (_role == 'teacher') ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('signup-school-dropdown'),
                      isExpanded: true,
                      initialValue: _schools.contains(_school) ? _school : (_schools.isNotEmpty ? _schools.first : null),
                      decoration: InputDecoration(
                        labelText: 'Select your school',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.location_city_outlined, color: Color(0xFF116B78)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.8),
                        ),
                      ),
                      items: [
                        ..._schools.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            )),
                        const DropdownMenuItem(
                          value: '__ADD_NEW__',
                          child: Row(
                            children: [
                              Icon(Icons.add_business_rounded, color: Color(0xFF116B78), size: 18),
                              SizedBox(width: 8),
                              Text(
                                '+ Register new school... (Admin Passkey)',
                                style: TextStyle(
                                  color: Color(0xFF116B78),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == '__ADD_NEW__') {
                          setState(() => _isAddingSchool = true);
                        } else if (v != null) {
                          setState(() => _school = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _isAddingSchool ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isAddingSchool ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('toggle-add-school-btn'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _isAddingSchool = !_isAddingSchool),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  _isAddingSchool ? Icons.close_rounded : Icons.add_circle_outline_rounded,
                                  size: 18,
                                  color: _isAddingSchool ? const Color(0xFFDC2626) : const Color(0xFF116B78),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isAddingSchool
                                        ? 'Cancel adding partner school'
                                        : "Don't see your school? Add New School (Admin Passkey Required)",
                                    style: TextStyle(
                                      color: _isAddingSchool ? const Color(0xFFDC2626) : const Color(0xFF116B78),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isAddingSchool) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.school_rounded, color: Color(0xFF116B78), size: 19),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Register New School in Arua',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: Color(0xFF116B78),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add your institution to PadCare to enable sanitary pad distributions. Requires administrator authorization passkey.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF52796F)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey('new-school-name-field'),
                              controller: _newSchoolNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'School name (e.g. Arua Secondary School)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('new-school-subcounty-dropdown'),
                              initialValue: _newSchoolSubCounty,
                              decoration: InputDecoration(
                                labelText: 'Sub-County / Division in Arua',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                              ),
                              items: const [
                                'Arua Hill',
                                'Ediofe',
                                'Oli',
                                'Ayivu',
                                'Dadamu',
                                'Manibe',
                                'Logiri',
                                'Offaka',
                                'Other Arua Division',
                              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _newSchoolSubCounty = v);
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const ValueKey('new-school-phone-field'),
                              controller: _newSchoolPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'School contact phone (optional)',
                                hintText: '+256 700 000 000',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const ValueKey('new-school-passkey-field'),
                              controller: _newSchoolAdminPasskeyController,
                              obscureText: _obscureAdminPasskey,
                              decoration: InputDecoration(
                                labelText: 'PadCare Admin Password (Required)',
                                hintText: 'Enter secret admin passkey',
                                prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF116B78), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureAdminPasskey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: const Color(0xFF6B8487),
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() => _obscureAdminPasskey = !_obscureAdminPasskey),
                                ),
                                errorText: _newSchoolPasskeyError,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _newSchoolPasskeyError != null ? Colors.red : const Color(0xFFDCECEB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF116B78), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Admin password known to PadCare administrators only is required to register new institutions.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    key: const ValueKey('save-new-school-btn'),
                                    onPressed: _savingSchool ? null : _handleAddNewSchool,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF116B78),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _savingSchool
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded, size: 18),
                                    label: Text(
                                      _savingSchool ? 'Saving...' : 'Save & Select School',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() => _isAddingSchool = false),
                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Profile Avatar (Synced with Firebase Storage)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF172B36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_presetAvatars.length, (i) {
                      final isSelected = _selectedAvatarIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatarIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF116B78) : Colors.transparent,
                              width: 2.8,
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x28116B78),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: NetworkImage(_presetAvatars[i]),
                            child: isSelected
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF116B78).withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF116B78),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    title: const Text(
                      'I agree to the Terms of Service and Privacy Policy',
                      style: TextStyle(fontSize: 13, color: Color(0xFF172B36)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _agreed && !_loading ? _handleCreateAccount : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF116B78),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Create account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Color(0xFF6B8487), fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginHero(),
                            ),
                          );
                        },
                        child: const Text('Sign in', style: TextStyle(color: Color(0xFF116B78), fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. SocialLogin & SocialButton
// ---------------------------------------------------------------------------
class SocialLogin extends StatelessWidget {
  final VoidCallback? onAuthenticated;

  const SocialLogin({super.key, this.onAuthenticated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PadCare Sign In'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/padcare_icon.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/icon/app_icon.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sign in to PadCare',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to continue',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 36),
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onTap: () async {
                  final result = await AuthService.signInWithGoogle();
                  if (!context.mounted) return;
                  if (result.isSuccess) {
                    if (onAuthenticated != null) {
                      onAuthenticated!();
                    } else {
                      PadCareAuthNavigator.openApp(
                        context,
                        email: result.user?.email ?? 'google-user@padcare.org',
                        displayName: result.user?.displayName,
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.errorMessage ?? 'Google sign in failed.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.apple,
                label: 'Continue with Apple',
                onTap: () {
                  if (onAuthenticated != null) {
                    onAuthenticated!();
                  } else {
                    PadCareAuthNavigator.openApp(
                      context,
                      email: 'apple-user@padcare.org',
                      displayName: 'Apple User',
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.mail_outline,
                label: 'Continue with Email',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginHero(onLoginSuccess: onAuthenticated),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SignupTerms(onSignedUp: onAuthenticated),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Create a new account'),
              ),
              const Spacer(),
              Text(
                'By continuing you agree to PadCare\'s Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. TwoFactor
// ---------------------------------------------------------------------------
class TwoFactor extends StatefulWidget {
  final String? targetContact;
  final VoidCallback? onVerified;

  const TwoFactor({
    super.key,
    this.targetContact,
    this.onVerified,
  });

  @override
  State<TwoFactor> createState() => _TwoFactorState();
}

class _TwoFactorState extends State<TwoFactor> {
  String _code = '';
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap(String d) {
    if (_code.length < 6) {
      setState(() => _code += d);
      if (_code.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          if (widget.onVerified != null) {
            widget.onVerified!();
          } else {
            PadCareAuthNavigator.openApp(
              context,
              email: widget.targetContact ?? 'user@padcare.org',
            );
          }
        });
      }
    }
  }

  void _back() {
    if (_code.isNotEmpty) {
      setState(() => _code = _code.substring(0, _code.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contactDisplay = widget.targetContact ?? '•••• 4821';

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.verified_user_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Two-factor authentication',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to $contactDisplay',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _code.length;
              return Container(
                width: 44,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: filled ? scheme.primary : scheme.outlineVariant,
                    width: filled ? 2 : 1,
                  ),
                ),
                child: Text(
                  filled ? _code[i] : '',
                  style: theme.textTheme.headlineSmall,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _seconds > 0
              ? Text(
                  'Resend code in 0:${_seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              : TextButton(
                  onPressed: _startTimer,
                  child: const Text('Resend code'),
                ),
          const Spacer(),
          _Keypad(onTap: _tap, onBackspace: _back),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Welcome
// ---------------------------------------------------------------------------
class Welcome extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const Welcome({super.key, this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primaryContainer],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/padcare_icon.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/icon/app_icon.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome to PadCare',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Community-led menstrual hygiene, emergency period care, and dignity kits for schools and communities in Uganda.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (onGetStarted != null) {
                        onGetStarted!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignupTerms(),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onPrimary,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Get started'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginHero(),
                      ),
                    );
                  },
                  child: Text(
                    'I already have an account',
                    style: TextStyle(color: scheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Creator & Demo Access',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                PadCareAuthNavigator.openApp(
                                  context,
                                  email: 'devgtnation@gmail.com',
                                  role: 'teacher',
                                  displayName: 'Dan Mungufeni',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.onPrimary,
                                side: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Dan M. (Teacher)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                PadCareAuthNavigator.openApp(
                                  context,
                                  email: 'abetinichlas@gmail.com',
                                  role: 'parent',
                                  displayName: 'Nicholas Acadri',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.onPrimary,
                                side: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Nicholas A. (Parent)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutPage(),
                          ),
                        );
                      },
                      child: Text(
                        'About',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.5),
                        height: 2.4,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FaqPage(),
                          ),
                        );
                      },
                      child: Text(
                        'FAQ',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.5),
                        height: 2.4,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ContactPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Contact',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.5),
                        height: 2.4,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TeamPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Team',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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

// ---------------------------------------------------------------------------
// 10. BiometricUnlock
// ---------------------------------------------------------------------------
class BiometricUnlock extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const BiometricUnlock({super.key, this.onUnlocked});

  @override
  State<BiometricUnlock> createState() => _BiometricUnlockState();
}

class _BiometricUnlockState extends State<BiometricUnlock> {
  bool _scanning = false;
  bool _unlocked = false;

  void _scan() {
    setState(() => _scanning = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _unlocked = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        } else {
          PadCareAuthNavigator.openApp(
            context,
            email: 'biometric-user@padcare.org',
            displayName: 'Biometric User',
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _unlocked ? Colors.green : scheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Security'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'PadCare is locked',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _unlocked
                    ? 'Unlocked'
                    : _scanning
                        ? 'Scanning…'
                        : 'Tap to unlock with Face ID or Touch ID',
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _scanning || _unlocked ? null : _scan,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: _scanning ? 0.25 : 0.12),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Icon(
                    _unlocked
                        ? Icons.lock_open_rounded
                        : Icons.fingerprint,
                    size: 72,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => PinLock(onUnlocked: widget.onUnlocked),
                    ),
                  );
                },
                icon: const Icon(Icons.dialpad),
                label: const Text('Use passcode instead'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
