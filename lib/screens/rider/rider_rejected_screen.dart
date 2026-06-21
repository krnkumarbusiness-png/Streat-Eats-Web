import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class RiderRejectedScreen extends StatelessWidget {
  final String? reason;
  const RiderRejectedScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.error, width: 2),
                ),
                child: const Center(
                  child: Text('❌', style: TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Application Reject Ho Gayi',
                style: AppStyles.screenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (reason != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    'Reason: $reason',
                    style: AppStyles.bodyText.copyWith(
                      color: AppColors
                          .textPrimary, // ✅ was default (inherited white in dark theme)
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Koi baat nahi bhai! Instagram pe DM karo\n@streeteats.hld pe clarification ke liye.',
                style: AppStyles.bodyText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    await AuthService().logout();
                    if (context.mounted) {
                      // ✅ named route nahi — direct MaterialPageRoute (project rule)
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Wapas Jao',
                    style: AppStyles.screenTitle.copyWith(
                      fontSize: 18,
                      color: Colors
                          .white, // ✅ button text = white on red bg — intentional
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
