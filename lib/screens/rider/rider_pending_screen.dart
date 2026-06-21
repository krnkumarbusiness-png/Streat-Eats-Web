import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class RiderPendingScreen extends StatelessWidget {
  const RiderPendingScreen({super.key});

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
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warning, width: 2),
                ),
                child: const Center(
                  child: Text('⏳', style: TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Application Submit Ho Gayi!',
                style: AppStyles.screenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Bhai, teri application review ho rahi hai.\nAdmin approve karega toh turant notification aayega.',
                style: AppStyles.bodyText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildStep('✅', 'Application Submit', true),
              _buildStep('🔄', 'Admin Review (24-48 hours)', false),
              _buildStep('🚀', 'Rider Dashboard Unlock', false),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('📱 Instagram pe follow karo',
                        style: AppStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text('@streeteats.hld',
                        style: AppStyles.bodyText
                            .copyWith(color: AppColors.primary)),
                    const SizedBox(height: 8),
                    const Text('Updates ke liye connected raho!',
                        style: AppStyles.bodyText),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () async {
                  try {
                    await AuthService().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Logout failed, dobara try karo',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Logout',
                  style: AppStyles.bodyText.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String emoji, String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppStyles.bodyText.copyWith(
              color: isDone ? AppColors.textPrimary : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
