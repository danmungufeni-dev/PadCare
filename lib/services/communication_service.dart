import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum EmailLaunchTarget {
  emailApp,
  gmailWeb,
}

/// Centralized communication service for dialing phone calls, sending SMS messages,
/// launching WhatsApp chats, and sending emails (email app or Gmail website).
class CommunicationService {
  /// Clean phone numbers by removing spaces, brackets, hyphens, and dots.
  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\(\)\-\.]'), '');
  }

  /// Converts a Ugandan or general phone number into WhatsApp international format without leading '+' or '0'.
  static String formatForWhatsApp(String phone) {
    var clean = cleanPhoneNumber(phone);
    if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }
    // Uganda local prefix replacement: 07xx / 08xx -> 2567xx / 2568xx
    if (clean.startsWith('0') && clean.length >= 10) {
      clean = '256${clean.substring(1)}';
    }
    return clean;
  }

  /// Switch to the phone app with the phone number dialed.
  static Future<bool> makeCall(BuildContext context, String phone) async {
    final clean = cleanPhoneNumber(phone);
    final uri = Uri(scheme: 'tel', path: clean);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Dialing $phone in phone app...')),
              ],
            ),
            backgroundColor: const Color(0xFF116B78),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $phone: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }

  /// Switch to the default SMS / Messaging app with the phone number.
  static Future<bool> sendSms(BuildContext context, String phone, {String? body}) async {
    final clean = cleanPhoneNumber(phone);
    final uri = Uri(
      scheme: 'sms',
      path: clean,
      queryParameters: (body != null && body.isNotEmpty) ? {'body': body} : null,
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Opening messaging app for $phone...')),
              ],
            ),
            backgroundColor: const Color(0xFF116B78),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open messaging app for $phone: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }

  /// Launch WhatsApp with prefilled message to the phone number.
  static Future<bool> openWhatsApp(
    BuildContext context,
    String phone, {
    String? message,
  }) async {
    final waPhone = formatForWhatsApp(phone);
    final query = (message != null && message.isNotEmpty)
        ? '?text=${Uri.encodeComponent(message)}'
        : '';
    final url = 'https://wa.me/$waPhone$query';
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Opening WhatsApp for $phone...')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp for $phone: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }

  /// Launch the native email app (mailto:).
  static Future<bool> launchEmailApp(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Opening email app for $email...')),
              ],
            ),
            backgroundColor: const Color(0xFF116B78),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        // Fallback to Gmail Web if mailto fails
        return launchGmailWeb(context, email, subject: subject, body: body);
      }
      return false;
    }
  }

  /// Redirect to the Gmail website compose screen (browser).
  static Future<bool> launchGmailWeb(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    final suParam = subject != null ? '&su=${Uri.encodeComponent(subject)}' : '';
    final bodyParam = body != null ? '&body=${Uri.encodeComponent(body)}' : '';
    final url = 'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(email.trim())}$suParam$bodyParam';
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.language_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Opening Gmail website for $email...')),
              ],
            ),
            backgroundColor: const Color(0xFFD93025),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Gmail website for $email: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }

  /// Present a bottom sheet modal to choose between opening the Email App or the Gmail Website.
  static Future<void> promptEmailOptions(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mail_outline_rounded, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send Email',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.email_outlined, color: Color(0xFF116B78)),
                ),
                title: const Text('Default Email App', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Open in your device\'s default mail client'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  launchEmailApp(context, email, subject: subject, body: body);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFEE2E2)),
                ),
                tileColor: const Color(0xFFFFF5F5),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mail_rounded, color: Color(0xFFDC2626)),
                ),
                title: const Text('Gmail Website', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Redirect directly to mail.google.com compose'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFFDC2626)),
                onTap: () {
                  Navigator.pop(ctx);
                  launchGmailWeb(context, email, subject: subject, body: body);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show comprehensive contact options modal with Call, SMS Message, and WhatsApp.
  static Future<void> showContactOptionsModal(
    BuildContext context, {
    required String phone,
    String? email,
    String? title,
    String? defaultMessage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title ?? 'Contact Options',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF116B78),
                ),
              ),
              const SizedBox(height: 18),
              // Call Option
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text('Phone Call', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Switch to phone app and dial number'),
                trailing: const Icon(Icons.call_made_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  makeCall(context, phone);
                },
              ),
              const SizedBox(height: 10),
              // SMS Message Option
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sms_rounded, color: Color(0xFF7C3AED)),
                ),
                title: const Text('Send SMS Message', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Open device messaging app'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  sendSms(context, phone, body: defaultMessage);
                },
              ),
              const SizedBox(height: 10),
              // WhatsApp Option
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFDCFCE7)),
                ),
                tileColor: const Color(0xFFF0FDF4),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('WhatsApp Chat', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                subtitle: const Text('Chat or send details directly on WhatsApp'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF16A34A)),
                onTap: () {
                  Navigator.pop(ctx);
                  openWhatsApp(context, phone, message: defaultMessage);
                },
              ),
              if (email != null && email.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Email Option
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.email_outlined, color: Color(0xFFD97706)),
                  ),
                  title: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    promptEmailOptions(context, email);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
