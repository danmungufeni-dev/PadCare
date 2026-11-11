import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../main.dart';

/// Screen displayed to school teachers/staff whose account is awaiting administrative approval in Firebase.
class TeacherPendingApprovalScreen extends StatefulWidget {
  const TeacherPendingApprovalScreen({
    super.key,
    required this.teacherName,
    required this.school,
    required this.uid,
    required this.email,
    required this.onSignOut,
  });

  final String teacherName;
  final String school;
  final String uid;
  final String email;
  final VoidCallback onSignOut;

  @override
  State<TeacherPendingApprovalScreen> createState() => _TeacherPendingApprovalScreenState();
}

class _TeacherPendingApprovalScreenState extends State<TeacherPendingApprovalScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (FirestoreService.isPreverifiedDemoEmail(widget.email) ||
        FirestoreService.isPreverifiedDemoEmail(widget.uid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkVerificationStatus();
      });
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _checking = true);
    final profile = await FirestoreService.getUserProfile(widget.uid);
    if (!mounted) return;
    setState(() => _checking = false);

    if (profile != null && profile.authorized && profile.status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Your teacher account has been verified! Welcome to PadCare.'),
          backgroundColor: Color(0xFF116B78),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            facility: widget.school,
            teacherName: widget.teacherName,
            onSignOut: widget.onSignOut,
            isVerifiedStaff: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification pending. An administrator will verify your school affiliation in Firebase shortly.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showContactAdminDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: Color(0xFF116B78)),
            SizedBox(width: 10),
            Text('PadCare Administration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you need urgent verification for an active school distribution, please contact our Arua City coordination team:',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: Color(0xFF116B78)),
                      SizedBox(width: 8),
                      Text('+256 772 100 200', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: Color(0xFF116B78)),
                      SizedBox(width: 8),
                      Text('admin@padcare.org', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF116B78), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAdminQuickAuthorizeDialog() {
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? errorText;
    bool authorizing = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF116B78), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Admin Authorization', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the PadCare Administrator Passkey to authorize ${widget.teacherName} for ${widget.school}.',
                style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('admin-passkey-field'),
                controller: passwordCtrl,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  hintText: 'Enter secret admin passkey',
                  prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF116B78)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF6B8487),
                      size: 20,
                    ),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFDCECEB)),
                  ),
                ),
                onSubmitted: (_) {
                  final pass = passwordCtrl.text;
                  if (!FirestoreService.verifyAdminPasskey(pass)) {
                    setDialogState(() {
                      errorText = 'Incorrect admin password. Access denied.';
                    });
                    return;
                  }
                },
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Restricted: known only to PadCare system administrators.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton(
              key: const ValueKey('confirm-admin-auth-btn'),
              onPressed: authorizing
                  ? null
                  : () async {
                      final pass = passwordCtrl.text;
                      if (!FirestoreService.verifyAdminPasskey(pass)) {
                        setDialogState(() {
                          errorText = 'Incorrect admin password. Access denied.';
                        });
                        return;
                      }
                      setDialogState(() {
                        authorizing = true;
                        errorText = null;
                      });
                      await FirestoreService.approveStaffUser(
                        uid: widget.uid,
                        authorized: true,
                        status: 'approved',
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _checkVerificationStatus();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF116B78),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(authorizing ? 'Verifying...' : 'Authorize Staff'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF172B36);
    const muted = Color(0xFF6B8487);
    const deepTeal = Color(0xFF116B78);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            BrandMark(),
            SizedBox(width: 8),
            Text(
              'PadCare',
              style: TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: ink),
            onPressed: widget.onSignOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFD97706),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '⏳ Verification Pending',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Teacher Verification Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hello ${widget.teacherName}, your account for ${widget.school} has been submitted.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 20, color: deepTeal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.school,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded, size: 18, color: muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.email,
                                style: const TextStyle(color: muted, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                        if (widget.uid.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.fingerprint_rounded, size: 18, color: muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SelectableText(
                                  'UID: ${widget.uid}',
                                  style: const TextStyle(color: muted, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'For child safeguarding and stock integrity, senior woman teacher portals are authorized by PadCare administrators in Firebase before access to school stock is granted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _checking ? null : _checkVerificationStatus,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_checking ? 'Checking Firebase...' : 'Check Verification Status'),
                    style: FilledButton.styleFrom(
                      backgroundColor: deepTeal,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await AuthService.sendEmailVerification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.isSuccess
                              ? 'Verification email sent to ${widget.email}. Please check your inbox or spam folder.'
                              : (res.errorMessage ?? 'Failed to send email.')),
                          backgroundColor: res.isSuccess ? const Color(0xFF116B78) : Colors.redAccent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Resend Verification Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF116B78),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _showContactAdminDialog,
                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                    label: const Text('Contact PadCare Admin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: deepTeal,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    key: const ValueKey('admin-quick-authorize-btn'),
                    onPressed: _showAdminQuickAuthorizeDialog,
                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                    label: const Text('Admin Quick-Authorize (Passkey Protected)'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text(
                      'Sign Out and Return',
                      style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
