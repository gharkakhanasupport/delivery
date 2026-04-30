import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';

/// Big OTP display card shown to delivery partner.
/// Partner reads the digits aloud to cook (pickup) or customer (delivery).
/// Tap to copy.
class OtpDisplayCard extends StatelessWidget {
  final String label;
  final String otp;
  final String instruction;
  final Color accent;
  final IconData icon;

  const OtpDisplayCard({
    super.key,
    required this.label,
    required this.otp,
    required this.instruction,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final digits = otp.split('');

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: otp));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP copied: $otp'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(Icons.copy, size: 16, color: accent.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: digits
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 48,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          d,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Text(
              instruction,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
