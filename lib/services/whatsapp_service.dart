import 'url_launcher_stub.dart'
    if (dart.library.html) 'url_launcher_web.dart';

class WhatsAppService {
  /// PadCare official helpline number in Arua City (UG).
  /// Format: Country code without leading '+' or '0'.
  static const String helplinePhone = '256700000000';

  /// Generates a human-friendly verification code for WhatsApp verification.
  static String generateVerificationCode() {
    final randomDigits = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    return 'PAD-$randomDigits';
  }

  /// Builds a WhatsApp Click-to-Chat URL with prefilled verification details.
  static String buildWhatsAppUrl({
    required String phone,
    required String code,
    String? name,
    String? school,
    bool isTeacher = false,
  }) {
    final roleText = isTeacher
        ? 'Senior Woman Teacher (${school ?? "School"})'
        : 'Parent / Community Member';
    final userLabel = (name != null && name.trim().isNotEmpty) ? name.trim() : 'PadCare User';

    final message = 'Hello PadCare! Please verify my account:\n'
        '• Role: $roleText\n'
        '• Name: $userLabel\n'
        '• Phone: $phone\n'
        '• Verification Code: $code';

    final encoded = Uri.encodeComponent(message);
    return 'https://wa.me/$helplinePhone?text=$encoded';
  }

  /// Launches the WhatsApp chat with the pre-filled verification message.
  static Future<bool> launchWhatsApp({
    required String phone,
    required String code,
    String? name,
    String? school,
    bool isTeacher = false,
  }) async {
    final url = buildWhatsAppUrl(
      phone: phone,
      code: code,
      name: name,
      school: school,
      isTeacher: isTeacher,
    );
    try {
      openExternalUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends or opens a WhatsApp notification for a ready package
  static Future<bool> sendPickupNotification({
    required String reference,
    required String school,
    String? recipientPhone,
  }) async {
    final message = 'Hello! Your confidential PadCare package (Ref: $reference) is packed and ready for pickup at $school with the Senior Woman Teacher.';
    final target = (recipientPhone != null && recipientPhone.trim().isNotEmpty)
        ? recipientPhone.replaceAll(RegExp(r'[\s\+\-]'), '')
        : '';
    final url = target.isNotEmpty
        ? 'https://wa.me/$target?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(message)}';
    try {
      openExternalUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens a WhatsApp chat with any custom text message.
  static Future<bool> launchMessage({
    String? phone,
    required String message,
  }) async {
    final target = (phone != null && phone.trim().isNotEmpty)
        ? phone.replaceAll(RegExp(r'[\s\+\-]'), '')
        : '';
    final url = target.isNotEmpty
        ? 'https://wa.me/$target?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(message)}';
    try {
      openExternalUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
