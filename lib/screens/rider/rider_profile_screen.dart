import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../providers/rider_provider.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import '../login_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _riderService = RiderService();

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: isError ? 3 : 2),
    ));
  }

  void _showEditProfileDialog(String currentName, String currentArea) {
    final nameCtrl = TextEditingController(text: currentName);
    final areaCtrl = TextEditingController(text: currentArea);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Profile',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name required'
                        : null),
                const SizedBox(height: 14),
                _dialogField(
                    controller: areaCtrl,
                    label: 'Delivery Area',
                    hint: 'e.g. Haldwani',
                    icon: Icons.location_on_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Area required'
                        : null),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textMuted, fontFamily: 'Poppins')),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final userId = _supabase.auth.currentUser?.id;
                          if (userId == null) return;
                          await _supabase.from('riders').update({
                            'full_name': nameCtrl.text.trim(),
                            'area': areaCtrl.text.trim(),
                          }).eq('id', userId);
                          await context
                              .read<RiderProvider>()
                              .fetchRiderProfile();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _snack('Profile updated! ✅');
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          _snack('Update failed', isError: true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpiDialog(String? currentUpi) {
    final ctrl = TextEditingController(text: currentUpi ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update UPI ID',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins')),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
              fontSize: 13),
          decoration: InputDecoration(
            hintText: 'yourname@upi',
            hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
                fontSize: 13),
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.primary, size: 18),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () async {
              final upi = ctrl.text.trim();
              if (upi.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _riderService.updateUpiId(upi);
                await context.read<RiderProvider>().fetchRiderProfile();
                _snack('UPI ID updated!');
              } catch (e) {
                _snack('Update failed', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: const Text('Kya sach mein logout karna hai?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, elevation: 0),
            child: const Text('Logout',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  // ── Availability Toggle — FIXED ───────────────────────────────
  // ✅ FIX: activeThumbColor deprecated hai Flutter 3.x mein
  // thumbColor aur trackColor use karo MaterialStateProperty se
  Widget _buildAvailabilitySwitch(bool isAvailable) {
    return Switch(
      value: isAvailable,
      onChanged: (val) async {
        try {
          await _riderService.toggleAvailability(val);
          await context.read<RiderProvider>().fetchRiderProfile();
          _snack(val ? 'Online ho gaye! ✅' : 'Offline ho gaye');
        } catch (e) {
          _snack('Update failed', isError: true);
        }
      },
      // ✅ FIXED: MaterialStateProperty use karo
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.success;
        }
        return AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.success.withOpacity(0.3);
        }
        return AppColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderProvider>(
      builder: (context, riderProvider, _) {
        final rider = riderProvider.rider;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Header ──────────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                child: Row(children: [
                  const Expanded(
                    child: Text('My Profile',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Poppins')),
                  ),
                  GestureDetector(
                    onTap: () => _showEditProfileDialog(
                        rider?.fullName ?? '', rider?.area ?? ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2))),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_outlined,
                            color: AppColors.primary, size: 14),
                        SizedBox(width: 5),
                        Text('Edit',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins')),
                      ]),
                    ),
                  ),
                ]),
              ),

              // ── Profile Card ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Center(
                        child: Text('🛵', style: TextStyle(fontSize: 34))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(rider?.fullName ?? 'Rider',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(rider?.phone ?? '',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(rider?.area ?? 'Haldwani',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                        ]),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.4)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(rider?.status ?? 'approved',
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins')),
                          ]),
                        ),
                      ])),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Stats Row ─────────────────────────────────────
              Row(children: [
                _statCard(
                    '🏆',
                    'Total Earned',
                    '₹${(rider?.totalEarnings ?? 0).toStringAsFixed(0)}',
                    AppColors.success),
                const SizedBox(width: 10),
                _statCard('🏍️', 'Vehicle', rider?.vehicleType ?? 'Bike',
                    AppColors.primary),
                const SizedBox(width: 10),
                _statCard(
                    '📍', 'Area', rider?.area ?? 'Haldwani', AppColors.warning),
              ]),

              const SizedBox(height: 14),

              // ── UPI Card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('UPI ID',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          rider?.upiId ?? 'Not added — add for weekly payouts',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: rider?.upiId != null
                                  ? AppColors.textSecondary
                                  : AppColors.error),
                        ),
                      ])),
                  GestureDetector(
                    onTap: () => _showUpiDialog(rider?.upiId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2))),
                      child: Text(rider?.upiId != null ? 'Edit' : 'Add',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins')),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Availability Toggle — FIXED ───────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: (rider?.isAvailable ?? false)
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.circle,
                        color: (rider?.isAvailable ?? false)
                            ? AppColors.success
                            : AppColors.error,
                        size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Availability',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          (rider?.isAvailable ?? false)
                              ? 'Online — accepting orders'
                              : 'Offline — not accepting orders',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: (rider?.isAvailable ?? false)
                                  ? AppColors.success
                                  : AppColors.textMuted),
                        ),
                      ])),
                  // ✅ FIXED switch widget
                  _buildAvailabilitySwitch(rider?.isAvailable ?? false),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Menu Section ──────────────────────────────────
              _sectionCard(children: [
                _menuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About Street Eats',
                  onTap: _showAboutDialog,
                ),
                _divider(),
                _menuItem(
                  icon: Icons.photo_camera_outlined,
                  label: 'Follow @streeteats.hld',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 12),

              // ── Logout ────────────────────────────────────────
              _sectionCard(children: [
                _menuItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  color: AppColors.error,
                  onTap: _logout,
                ),
              ]),

              const SizedBox(height: 24),

              const Text(
                'Street Eats v1.0.0 • Rider App\nMade with ❤️ in Haldwani',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ]),
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🍽️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('About Street Eats',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
        ]),
        content: const Text(
          'Street Eats is Haldwani\'s first hyperlocal street food delivery app — built by a local, for locals.\n\n'
          '🏠 Only Haldwani\n'
          '🥟 Street food only\n'
          '⚡ Under 30 min delivery\n'
          '🕔 Open 5 PM – 9 PM daily\n\n'
          '"Ghar Baithe Street Ka Swad" 🧡',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFamily: 'Poppins'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontFamily: 'Poppins'),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: children),
      );

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final iconColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color ?? AppColors.textPrimary)),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(height: 1, color: AppColors.border),
      );

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
        validator: validator,
      );
}
