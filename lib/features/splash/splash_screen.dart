import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const Color _greenPale = Color(0xFFE4F8F2);
const Color _paper = Color(0xFFFBFDFD);
const Color _ink = Color(0xFF172B36);
const Color _deepTeal = Color(0xFF116B78);
const Color _green = Color(0xFF35B9B4);

const String _fontHeading = 'Outfit';
const String _fontSubheading = 'PlusJakartaSans';

/// Full-screen branded splash preview screen with animated logo and tagline.
class PadCareSplashScreen extends StatelessWidget {
  const PadCareSplashScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greenPale,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_greenPale, _paper],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (onClose != null)
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: _ink),
                    onPressed: onClose,
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33116B78),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/padcare_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/padcare_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'PadCare',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        fontFamily: _fontHeading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PadCare Network • Menstrual Health & Dignity',
                      style: TextStyle(
                        color: _deepTeal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: _fontSubheading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dignity, Freedom & Care within reach.',
                      style: TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        fontFamily: _fontSubheading,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Lottie.asset(
                        'assets/loading-transparent.json',
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_green),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _PadCareSplashScreen = PadCareSplashScreen;
