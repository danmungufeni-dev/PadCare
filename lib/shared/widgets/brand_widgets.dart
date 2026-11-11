import 'package:flutter/material.dart';

const Color _brandInk = Color(0xFF172B36);
const Color _brandMuted = Color(0xFF6B8487);
const Color _brandGreen = Color(0xFF35B9B4);
const Color _brandGreenPale = Color(0xFFE4F8F2);
const Color _brandCoral = Color(0xFF0D9488);
const Color _brandLine = Color(0xFFDCECEB);

/// Displays the PadCare logomark icon inside a curved white card.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('padcare-logo'),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: const PadCareLogoPainter(),
          child: Image.asset(
            'assets/padcare_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header lockup with BrandMark, "PadCare" title, and "ARUA CITY" subtitle.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(),
        SizedBox(width: 8),
        Text(
          'PadCare',
          style: TextStyle(
            color: _brandInk,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'ARUA CITY',
          style: TextStyle(
            color: _brandMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Custom vector painter rendering the official PadCare sanitary pad symbol.
class PadCareLogoPainter extends CustomPainter {
  const PadCareLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final padPaint = Paint()..color = Colors.white;
    final wingPath = Path()
      ..moveTo(8.5, 8)
      ..lineTo(3.1, 6.1)
      ..quadraticBezierTo(1.9, 5.7, 2.3, 7.1)
      ..lineTo(4.5, 13.7)
      ..quadraticBezierTo(4.8, 14.6, 5.8, 14.2)
      ..lineTo(9, 12.8)
      ..close();
    canvas.drawPath(wingPath, padPaint);
    canvas.save();
    canvas.scale(-1, 1);
    canvas.translate(-24, 0);
    canvas.drawPath(wingPath, padPaint);
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 2.5, 8, 19),
        const Radius.circular(4),
      ),
      padPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10.2, 4.2, 3.6, 15.5),
        const Radius.circular(1.8),
      ),
      Paint()..color = const Color(0xFFFFD9D0),
    );

    final dropPath = Path()
      ..moveTo(12, 8.1)
      ..cubicTo(10.6, 10, 9.4, 11.5, 9.4, 13.2)
      ..cubicTo(9.4, 14.9, 10.5, 16.1, 12, 16.1)
      ..cubicTo(13.5, 16.1, 14.6, 14.9, 14.6, 13.2)
      ..cubicTo(14.6, 11.5, 13.4, 10, 12, 8.1)
      ..close();
    canvas.drawPath(dropPath, Paint()..color = _brandCoral);
    canvas.drawCircle(
      const Offset(10.9, 12.5),
      0.65,
      Paint()..color = const Color(0xFFFFB6A7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Informational pill with shield icon reassuring anonymous, free, and safe operation.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _brandGreenPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: _brandGreen, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _brandGreen, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selection card for choosing portal access role.
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: _brandLine),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brandGreenPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _brandGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _brandInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _brandMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _brandMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom vector painter rendering the official Google "G" logo.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Red (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.35, 1.3, false, paint);

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -1.05, 1.25, false, paint);

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.2, 1.45, false, paint);

    // Blue (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 1.65, 1.1, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - strokeWidth * 0.2, center.dy - strokeWidth / 2, radius * 0.95, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom vector painter rendering the official WhatsApp logo.
class WhatsAppLogoPainter extends CustomPainter {
  const WhatsAppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Outer WhatsApp green circle
    final bgPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Inner white speech bubble with handset tail
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bubblePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.48), radius: radius * 0.62))
      ..moveTo(w * 0.35, h * 0.68)
      ..lineTo(w * 0.22, h * 0.80)
      ..lineTo(w * 0.45, h * 0.74)
      ..close();
    canvas.drawPath(bubblePath, whitePaint);

    // Green phone handset silhouette inside
    final phonePaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final phoneHandset = Path()
      ..moveTo(w * 0.38, h * 0.39)
      ..quadraticBezierTo(w * 0.36, h * 0.50, w * 0.49, h * 0.60)
      ..lineTo(w * 0.60, h * 0.61);
    canvas.drawPath(phoneHandset, phonePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
