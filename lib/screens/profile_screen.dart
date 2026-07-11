// dart:io removed — using XFile.readAsBytes() instead (web-safe)
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'order_history_screen.dart';
import '../providers/cart_provider.dart';
import '../services/storage_service.dart';
import 'donation_screen.dart';
import 'set_password_screen.dart';
import 'cart_screen.dart';
import '../constants/app_snackbar.dart';
import 'location_picker_screen.dart';
import 'address_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnackBar.showError(context, msg);
    } else {
      AppSnackBar.showSuccess(context, msg);
    }
  }

  // ── Profile Photo Upload ──────────────────────────────────────
  // Works on web (raw bytes via XFile.readAsBytes) and
  // native (with flutter_image_compress for size reduction).
  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Derive extension — picked.name is available on all platforms
      final ext = p.extension(picked.name).toLowerCase().isEmpty
          ? '.jpg'
          : p.extension(picked.name).toLowerCase();

      Uint8List uploadBytes;

      if (kIsWeb) {
        // On web: dart:io File doesn't exist.
        // XFile.readAsBytes() works via blob URL — fully web-safe.
        uploadBytes = await picked.readAsBytes();
      } else {
        // On native: compress to reduce size before uploading.
        final originalBytes = await picked.readAsBytes();
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            originalBytes,
            quality: 70,
            minWidth: 300,
            minHeight: 300,
            format: CompressFormat.jpeg,
          );
          uploadBytes = Uint8List.fromList(compressed);
        } catch (_) {
          // Compression failed — upload original bytes
          uploadBytes = originalBytes;
        }
      }

      final storageService = StorageService();
      final uploadedUrl = await storageService.uploadImage(
        uploadBytes,
        ext,
        folder: 'avatars',
      );
      if (uploadedUrl == null) throw Exception('Upload failed');
      final urlWithCacheBust =
          '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('users')
          .update({'avatar_url': urlWithCacheBust})
          .eq('id', userId);

      if (mounted) {
        await context.read<UserProvider>().fetchUserData();
        _snack('Profile photo updated! 🎉');
      }
    } catch (e) {
      if (mounted) _snack('Upload failed. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Edit Profile Dialog (Name + Area + Phone) ─────────────────
  void _showEditProfileDialog(
    BuildContext context,
    String currentName,
    String currentArea,
    String currentPhone,
  ) {
    final nameController = TextEditingController(text: currentName);
    final areaController = TextEditingController(text: currentArea);
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Profile', style: AppStyles.sectionHeader),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: areaController,
                      label: 'Area / Locality',
                      hint: 'e.g. Transport Nagar',
                      icon: Icons.location_on_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Area required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    // ── Phone Number Field ─────────────────────
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        hintText: '10-digit mobile number',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number required';
                        }
                        final digits = v.trim().replaceAll(' ', '');
                        if (digits.length != 10 ||
                            !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                          return 'Please enter a valid 10-digit Indian number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final userId = _supabase.auth.currentUser?.id;
                          if (userId == null) return;
                          await _supabase
                              .from('users')
                              .update({
                                'full_name': nameController.text.trim(),
                                'area': areaController.text.trim(),
                                'phone': phoneController.text.trim().replaceAll(
                                  ' ',
                                  '',
                                ),
                              })
                              .eq('id', userId);
                          if (mounted) {
                            await context.read<UserProvider>().fetchUserData();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack('Profile updated successfully! ✅');
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) _snack('Update failed.', isError: true);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Edit Delivery Address Dialog ──────────────────────────────
  void _showEditAddressDialog(
    BuildContext context,
    String currentAddress,
    String currentLandmark,
  ) {
    final addressController = TextEditingController(text: currentAddress);
    final landmarkController = TextEditingController(text: currentLandmark);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delivery Address',
              style: AppStyles.sectionHeader,
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: addressController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Address',
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      hintText: 'e.g. House No. 12, Sector 5, Transport Nagar',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.home_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _dialogField(
                    controller: landmarkController,
                    label: 'Landmark (Optional)',
                    hint: 'e.g. Near SBI ATM',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final userId = _supabase.auth.currentUser?.id;
                          if (userId == null) return;
                          final address = addressController.text.trim();
                          final landmark = landmarkController.text.trim();
                          await _supabase
                              .from('users')
                              .update({
                                'delivery_address': address,
                                'delivery_landmark': landmark,
                              })
                              .eq('id', userId);
                          if (mounted) {
                            context.read<UserProvider>().updateDeliveryAddress(
                              address,
                              landmark,
                            );
                            await context.read<UserProvider>().fetchUserData();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack('Delivery address saved! 📍');
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) _snack('Save failed.', isError: true);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── ACCOUNT DELETE ────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  Future<void> _deleteAccount(BuildContext context) async {
    // Step 1: Pehla confirmation dialog
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Account?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will permanently delete:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _deleteBullet('Your account and profile'),
            _deleteBullet('All order history'),
            _deleteBullet('Saved addresses and preferences'),
            _deleteBullet('Creator earnings (if any)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Yes, Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );

    if (step1 != true) return;

    // Step 2: Final confirmation — type "DELETE"
    final confirmController = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isTypedCorrect = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Final Confirmation',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.error,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Type "DELETE" below to confirm:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: AppColors.textMuted.withOpacity(0.5),
                      letterSpacing: 3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.error.withOpacity(0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    setDialogState(() => isTypedCorrect = v.trim() == 'DELETE');
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isTypedCorrect
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor: AppColors.error.withOpacity(0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Permanently Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (step2 != true) return;

    // Step 3: Actually delete karo
    setState(() => _isDeletingAccount = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not found');

      // 1. FCM tokens delete karo
      await _supabase.from('user_fcm_tokens').delete().eq('user_id', userId);

      // 2. Creator commissions delete karo (agar creator hai)
      try {
        final creator = await _supabase
            .from('creators')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        if (creator != null) {
          await _supabase
              .from('creator_commissions')
              .delete()
              .eq('creator_id', creator['id']);
          await _supabase.from('creators').delete().eq('user_id', userId);
        }
      } catch (_) {}

      // 3. Order items delete karo (orders ke through)
      try {
        final orders = await _supabase
            .from('orders')
            .select('id')
            .eq('user_id', userId);
        for (final order in orders) {
          await _supabase
              .from('order_items')
              .delete()
              .eq('order_id', order['id']);
        }
      } catch (_) {}

      // 4. Orders delete karo
      try {
        await _supabase.from('orders').delete().eq('user_id', userId);
      } catch (_) {}

      // 5. Donations delete karo
      try {
        await _supabase.from('donations').delete().eq('user_id', userId);
      } catch (_) {}

      // 6. Rider data delete karo (agar rider tha)
      try {
        await _supabase.from('riders').delete().eq('user_id', userId);
      } catch (_) {}

      // 7. Users table se delete karo
      await _supabase.from('users').delete().eq('id', userId);

      // 8. Cart clear karo
      await context.read<CartProvider>().clearCartOnLogout();

      // 9. Google sign out (agar Google user hai)
      try {
        await _authService.signOutGoogle();
      } catch (_) {}

      // 10. Supabase auth se delete karo
      // NOTE: Supabase se auth user delete ke liye
      // admin API chahiye. Isiliye hum auth.signOut karte hain
      // aur Supabase dashboard mein "delete_user" edge function
      // ya RPC banate hain. Abhi ke liye signOut karo.
      await _supabase.auth.signOut();

      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      context.read<UserProvider>().clearUser();

      // Login screen pe bhejo
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      // Success message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppSnackBar.showSuccess(
          context,
          'Account deleted. You are always welcome back! 🙏',
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        _snack('Delete failed: ${e.toString()}', isError: true);
      }
    }
  }

  Widget _deleteBullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.remove_circle_outline_rounded,
          color: AppColors.error,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  // ── About Dialog ──────────────────────────────────────────────
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('About Streat Eats', style: AppStyles.sectionHeader),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Streat Eats is Haldwani\'s first hyperlocal street food delivery app — built by a local, for locals.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _aboutRow(
                '🏠',
                'Hyper Local',
                'Only Haldwani. No big city chains — only your favourite local stalls.',
              ),
              _aboutRow(
                '🥟',
                'Street Food Only',
                'Momos, burgers, chowmein, pizza, chaat, maggi — all street food you love.',
              ),
              _aboutRow(
                '⚡',
                'Fast Delivery',
                'Delivered in under 30 minutes by people from your neighbourhood.',
              ),
              _aboutRow(
                '🕔',
                'Two Daily Shifts',
                'Order in both morning and evening shifts — exact timings shown on the home screen.',
              ),
              _aboutRow(
                '💯',
                'Trusted & Safe',
                'OTP-verified delivery, COD available, and fake-order protection.',
              ),
              const SizedBox(height: 10),
              _infoBox('"Ghar Baithe Street Ka Swad" 🧡'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rating & Review Dialog ────────────────────────────────
  void _showRatingDialog(BuildContext context) {
    int selectedStars = 0;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppColors.accent, // AppColors.accent = #FFD700
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rate Streat Eats ⭐',
                    style: AppStyles.sectionHeader,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How was your experience? Share your feedback!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Star Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedStars = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          star <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.accent,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedStars == 0
                      ? 'Please select a star rating'
                      : selectedStars == 1
                      ? 'Very bad 😞'
                      : selectedStars == 2
                      ? 'Not good 😕'
                      : selectedStars == 3
                      ? 'Okay 🙂'
                      : selectedStars == 4
                      ? 'Good experience! 😊'
                      : 'Excellent! 🔥',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedStars == 0
                        ? AppColors.textMuted
                        : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                // Feedback text field
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Kuch kehna hai? (optional)',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    counterStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Later',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              // Agar 4-5 stars → Play Store pe bhejo
              // Agar 1-3 stars → Bas thank you
              ElevatedButton(
                onPressed: selectedStars == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        if (selectedStars >= 4) {
                          // Play Store pe redirect
                          final playStoreUrl = Uri.parse(
                            'https://play.google.com/store/apps/details?id=com.streeteats.hld',
                            // ⚠️ YAHAN APNA ACTUAL PACKAGE NAME DAALO
                          );
                          if (await canLaunchUrl(playStoreUrl)) {
                            await launchUrl(
                              playStoreUrl,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                          if (mounted) _snack('Thank you for your review! ❤️');
                        } else {
                          // Low rating → WhatsApp pe feedback bhejo
                          final msg = Uri.encodeComponent(
                            'Streat Eats App Feedback ($selectedStars ⭐)\n\n${feedbackController.text.trim()}',
                          );
                          final wa = Uri.parse(
                            'https://wa.me/918630140017?text=$msg',
                            // ⚠️ YAHAN APNA WHATSAPP NUMBER DAALO
                          );
                          if (await canLaunchUrl(wa)) {
                            await launchUrl(
                              wa,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                          if (mounted) {
                            _snack('Feedback received! We will improve 🙏');
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedStars == 0
                      ? AppColors.textMuted
                      : AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  selectedStars >= 4 ? 'Rate on Play Store ⭐' : 'Submit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── FULL TERMS OF SERVICE ─────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Terms of Service', style: AppStyles.sectionHeader),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legalHeading('1. Acceptance of Terms'),
              const SizedBox(height: 6),
              const Text(
                'By downloading, installing, or using the Streat Eats app ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App. These Terms constitute a legally binding agreement between you ("User") and Streat Eats ("we", "our", "us").',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('2. Eligibility'),
              const SizedBox(height: 6),
              _bulletPoint(
                'You must be at least 13 years of age to use Streat Eats.',
              ),
              _bulletPoint(
                'You must provide a valid email address or Google account to register.',
              ),
              _bulletPoint(
                'You must provide a valid Indian mobile number (used for delivery contact and OTP).',
              ),
              _bulletPoint(
                'You must be located in or ordering for delivery within Haldwani, Uttarakhand.',
              ),
              _bulletPoint(
                'By registering, you confirm that all information provided is accurate and up-to-date.',
              ),
              const SizedBox(height: 14),
              _legalHeading('3. Account Registration & Security'),
              const SizedBox(height: 6),
              _bulletPoint(
                'You may register using Google Sign-In or email and password.',
              ),
              _bulletPoint(
                'You are responsible for maintaining the confidentiality of your login credentials.',
              ),
              _bulletPoint(
                'You must notify us immediately of any unauthorized use of your account.',
              ),
              _bulletPoint(
                'We reserve the right to suspend or terminate accounts that violate these Terms.',
              ),
              _bulletPoint(
                'Each user is permitted one account only. Multiple accounts are not allowed.',
              ),
              const SizedBox(height: 14),
              _legalHeading('4. App Usage & Operating Hours'),
              const SizedBox(height: 6),
              _bulletPoint(
                'The App is operational daily from 5:00 PM to 9:00 PM (IST) only.',
              ),
              _bulletPoint(
                'Orders placed outside these hours will not be accepted or processed.',
              ),
              _bulletPoint(
                'Last order acceptance closes at 8:45 PM to ensure timely delivery.',
              ),
              _bulletPoint(
                'Streat Eats reserves the right to change operating hours with or without prior notice.',
              ),
              _bulletPoint(
                'You are responsible for providing a correct and reachable delivery address.',
              ),
              _bulletPoint(
                'You must be available on your registered phone number during delivery.',
              ),
              const SizedBox(height: 14),
              _legalHeading('5. Orders & Payments'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Currently accepted payment method: Cash on Delivery (COD) and Online Payment via Razorpay (UPI, Cards, Net Banking).',
              ),
              _bulletPoint(
                'For new users, the first order must be paid online. COD unlocks from the second order onwards.',
              ),
              _bulletPoint('Maximum COD order value is ₹199 per order.'),
              _bulletPoint(
                'A platform fee of ₹5 is charged per order for app maintenance and operations.',
              ),
              _bulletPoint(
                'Delivery charges are calculated based on distance and are included in the food price.',
              ),
              _bulletPoint(
                'A packaging fee may be charged per order depending on vendor requirements.',
              ),
              _bulletPoint(
                'Prices shown are final. No hidden charges beyond what is displayed at checkout.',
              ),
              const SizedBox(height: 14),
              _legalHeading('6. Order Cancellation'),
              const SizedBox(height: 6),
              _bulletPoint(
                'You may cancel your order within 2 minutes of placing it.',
              ),
              _bulletPoint(
                'After 2 minutes, cancellation is strictly not allowed as food preparation begins.',
              ),
              _bulletPoint(
                'Repeated cancellations will result in account strikes and potential suspension.',
              ),
              const SizedBox(height: 14),
              _legalHeading('7. Delivery & OTP Confirmation'),
              const SizedBox(height: 6),
              _bulletPoint(
                'All deliveries are OTP-confirmed. A 4-digit OTP is sent to your registered email.',
              ),
              _bulletPoint(
                'The rider must enter the OTP to mark the order as delivered.',
              ),
              _bulletPoint(
                'Do not share your delivery OTP with anyone other than the Streat Eats rider.',
              ),
              _bulletPoint(
                'Delivery is currently available only within Haldwani city limits (within 4 km of the vendor).',
              ),
              const SizedBox(height: 14),
              _legalHeading('8. Prohibited Conduct'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Placing fake, prank, or intentionally incorrect orders.',
              ),
              _bulletPoint('Refusing to pay for COD orders after acceptance.'),
              _bulletPoint('Abusing or harassing riders, vendors, or staff.'),
              _bulletPoint(
                'Attempting to manipulate prices, offers, or referral systems fraudulently.',
              ),
              _bulletPoint(
                'Creating multiple accounts to exploit promotions or offers.',
              ),
              _bulletPoint(
                'Using the app for any unlawful or unauthorized purpose.',
              ),
              const SizedBox(height: 14),
              _legalHeading('9. Strike & Suspension Policy'),
              const SizedBox(height: 6),
              _bulletPoint(
                '1st offence (fake order / refusal to pay): Warning notification sent.',
              ),
              _bulletPoint(
                '2nd offence: Account suspended for 7 days. No orders can be placed.',
              ),
              _bulletPoint(
                '3rd offence: Account permanently blocked. No re-registration with the same details.',
              ),
              _bulletPoint(
                'Streat Eats reserves the right to determine what constitutes a violation.',
              ),
              const SizedBox(height: 14),
              _legalHeading('10. Account Deletion'),
              const SizedBox(height: 6),
              const Text(
                'You may delete your account at any time from the Profile screen. Upon deletion, all your personal data, order history, saved addresses, and creator earnings will be permanently erased. You may re-register with the same email after account deletion. However, previous order history and earnings will not be recoverable.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('11. Intellectual Property'),
              const SizedBox(height: 6),
              const Text(
                'All content within the Streat Eats app — including but not limited to the logo, brand name, UI design, text, and graphics — is the exclusive property of Streat Eats. You may not reproduce, distribute, or create derivative works without express written permission.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('12. Limitation of Liability'),
              const SizedBox(height: 6),
              const Text(
                'Streat Eats acts as a platform connecting customers with local food vendors. We are not responsible for the quality, hygiene, or quantity of food prepared by vendors. In case of a genuine issue, contact us within 30 minutes of delivery via Instagram @streateats.app.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('13. Changes to Terms'),
              const SizedBox(height: 6),
              const Text(
                'We reserve the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the revised Terms. We will notify users of significant changes via push notification.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('14. Governing Law'),
              const SizedBox(height: 6),
              const Text(
                'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in Uttarakhand, India.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('15. Contact Us'),
              const SizedBox(height: 6),
              const Text(
                'For any queries, disputes, or concerns regarding these Terms, please contact us on Instagram @streateats.app.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              _dateFooter('Last updated: May 11, 2026'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── FULL PRIVACY POLICY ───────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Privacy Policy', style: AppStyles.sectionHeader),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Streat Eats is committed to protecting your personal information and your right to privacy. This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('1. Information We Collect'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Email address — for account creation and login (via email/password or Google Sign-In).',
              ),
              _bulletPoint(
                'Full name — for personalisation and delivery communication.',
              ),
              _bulletPoint(
                'Phone number — for delivery contact, OTP verification, and rider coordination.',
              ),
              _bulletPoint(
                'Area / Locality — to show relevant nearby vendors.',
              ),
              _bulletPoint(
                'Delivery address — saved for faster future checkouts (you can edit or delete anytime).',
              ),
              _bulletPoint(
                'Device location (GPS) — to calculate delivery distance and show nearby vendors. We do not store your live location.',
              ),
              _bulletPoint(
                'FCM device token — to send order-related push notifications only.',
              ),
              _bulletPoint(
                'Order history — to display past orders and enable reordering.',
              ),
              _bulletPoint(
                'Payment information — we do NOT store card or UPI details. Payments are processed by Razorpay securely.',
              ),
              _bulletPoint(
                'Profile photo — if uploaded by you, stored on Supabase Storage.',
              ),
              const SizedBox(height: 14),
              _legalHeading('2. How We Use Your Information'),
              const SizedBox(height: 6),
              _bulletPoint(
                'To process and deliver your orders accurately and on time.',
              ),
              _bulletPoint(
                'To send push notifications about order status updates.',
              ),
              _bulletPoint('To calculate delivery distance and fees.'),
              _bulletPoint(
                'To enable customer support and resolve order issues.',
              ),
              _bulletPoint(
                'To run the Creator Program and calculate referral commissions.',
              ),
              _bulletPoint('To detect and prevent fraudulent or fake orders.'),
              _bulletPoint(
                'To improve our app experience based on usage patterns (anonymised data only).',
              ),
              const SizedBox(height: 14),
              _legalHeading('3. Data Sharing'),
              const SizedBox(height: 6),
              _bulletPoint(
                'We do NOT sell your personal data to any third-party advertisers or marketers.',
              ),
              _bulletPoint(
                'With the assigned delivery rider — only your name, phone number, and delivery address are shared, solely for delivery purposes.',
              ),
              _bulletPoint(
                'With the food vendor — only your order details (items ordered) are shared. No personal contact information.',
              ),
              _bulletPoint(
                'With Supabase — your data is stored securely on Supabase (a PostgreSQL-based cloud database).',
              ),
              _bulletPoint(
                'With Firebase — only device push tokens are shared for sending order notifications via FCM.',
              ),
              _bulletPoint(
                'With Razorpay — only when you choose online payment. Razorpay processes payments and is PCI-DSS compliant.',
              ),
              _bulletPoint(
                'With Google — only if you use Google Sign-In. We receive your name and email from Google.',
              ),
              const SizedBox(height: 14),
              _legalHeading('4. Data Retention'),
              const SizedBox(height: 6),
              const Text(
                'We retain your personal data as long as your account is active. If you delete your account, all personal data — including profile, order history, saved addresses, and creator data — is permanently deleted from our systems within 24 hours.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('5. Your Rights'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Access: You can view your profile data within the app at any time.',
              ),
              _bulletPoint(
                'Edit: You can update your name, phone, area, and delivery address from the Profile screen.',
              ),
              _bulletPoint(
                'Delete: You can permanently delete your account and all associated data from the Profile screen.',
              ),
              _bulletPoint(
                'Opt-out of notifications: You can disable push notifications from your device settings.',
              ),
              const SizedBox(height: 14),
              _legalHeading('6. Children\'s Privacy'),
              const SizedBox(height: 6),
              const Text(
                'Streat Eats is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we become aware that a child under 13 has provided us with personal data, we will promptly delete it.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('7. Security'),
              const SizedBox(height: 6),
              const Text(
                'We take data security seriously. All data is encrypted in transit using HTTPS/TLS. Our database is hosted on Supabase with row-level security (RLS) policies enabled. Passwords are hashed and never stored in plain text. However, no system is 100% secure — please use a strong password and do not share your account credentials.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('8. Third-Party Links'),
              const SizedBox(height: 6),
              const Text(
                'The app may contain links to external sites (e.g. Instagram). We are not responsible for the privacy practices of these external sites. We encourage you to review their privacy policies.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('9. Changes to This Policy'),
              const SizedBox(height: 6),
              const Text(
                'We may update this Privacy Policy from time to time. We will notify you of significant changes via push notification. Continued use of the App after changes constitutes acceptance of the updated policy.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('10. Contact Us'),
              const SizedBox(height: 6),
              const Text(
                'For any privacy-related queries or data deletion requests, contact us on Instagram @streateats.app.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              _dateFooter('Last updated: May 11, 2026'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── FULL REFUND & CANCELLATION ────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  void _showRefundDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.currency_rupee_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Refund & Cancellation',
                style: AppStyles.sectionHeader,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legalHeading('1. Order Cancellation Policy'),
              const SizedBox(height: 6),
              _bulletPoint(
                'You may cancel your order within 2 minutes of placing it from the Order Status screen.',
              ),
              _bulletPoint(
                'After 2 minutes, cancellation is not possible as food preparation has already started.',
              ),
              _bulletPoint(
                'If you placed a COD order and the rider has already picked up your order, cancellation is not permitted.',
              ),
              _bulletPoint(
                'Repeat cancellations will be flagged and may result in a temporary or permanent account block.',
              ),
              const SizedBox(height: 14),
              _legalHeading('2. Refund Policy — Cash on Delivery (COD)'),
              const SizedBox(height: 6),
              const Text(
                'For COD orders, since no advance payment is collected, monetary refunds are generally not applicable. However, in the following situations, we will take corrective action:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              _bulletPoint(
                'Wrong order delivered: We will arrange a replacement or issue a coupon credit for your next order.',
              ),
              _bulletPoint(
                'Incomplete order (missing items): Contact us within 30 minutes with photos. We will resolve promptly.',
              ),
              _bulletPoint(
                'Order never delivered but marked delivered: We will investigate and take action against the rider. A full refund via coupon will be issued.',
              ),
              const SizedBox(height: 14),
              _legalHeading('3. Refund Policy — Online Payment (Razorpay)'),
              const SizedBox(height: 6),
              _bulletPoint(
                'If your online payment was deducted but the order was not placed (technical failure), a full refund will be initiated within 5–7 business days to the original payment method.',
              ),
              _bulletPoint(
                'If the order was placed but not delivered due to our fault, a full refund will be initiated within 5–7 business days.',
              ),
              _bulletPoint(
                'Refunds for valid complaints on online-paid orders will be processed to the original payment source via Razorpay.',
              ),
              _bulletPoint(
                'Refunds will not be issued if the customer provided incorrect address details or was unavailable for delivery.',
              ),
              const SizedBox(height: 14),
              _legalHeading('4. Non-Refundable Situations'),
              const SizedBox(height: 6),
              _bulletPoint('Order cancelled after the 2-minute window.'),
              _bulletPoint(
                'Customer was unavailable or unreachable at the delivery address.',
              ),
              _bulletPoint('Customer provided incorrect address or landmark.'),
              _bulletPoint(
                'Order delivered correctly but customer changed their mind.',
              ),
              _bulletPoint('Complaints raised after 30 minutes of delivery.'),
              const SizedBox(height: 14),
              _legalHeading('5. How to Raise a Complaint'),
              const SizedBox(height: 6),
              const Text(
                'Contact us on Instagram @streateats.app within 30 minutes of delivery with the following:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              _bulletPoint('Your Order ID (visible in Order History)'),
              _bulletPoint('A clear photo of the issue'),
              _bulletPoint('A brief description of what went wrong'),
              const SizedBox(height: 8),
              const Text(
                'We aim to resolve all valid complaints within 24 hours.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              _dateFooter('Last updated: May 11, 2026'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── FULL DELIVERY POLICY ──────────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  void _showDeliveryPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Delivery Policy', style: AppStyles.sectionHeader),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legalHeading('1. Service Area'),
              const SizedBox(height: 6),
              const Text(
                'Streat Eats currently delivers only within Haldwani, Uttarakhand. We are expanding to Rudrapur, Ramnagar, and Nainital soon. Orders from outside Haldwani city limits will not be accepted.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              _legalHeading('2. Delivery Hours'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Streat Eats operates in two daily shifts — morning and evening.',
              ),
              _bulletPoint(
                'Live shift timings are shown on the Home screen and may vary by area or vendor.',
              ),
              _bulletPoint(
                'Orders are accepted only when at least one shift is currently active.',
              ),
              _bulletPoint(
                'We do not deliver on app maintenance days. We will inform users via push notification.',
              ),
              const SizedBox(height: 14),
              _legalHeading('3. Estimated Delivery Time'),
              const SizedBox(height: 6),
              _bulletPoint(
                'Estimated delivery time is shown on the vendor card and checkout screen.',
              ),
              _bulletPoint(
                'Average delivery time is 15–30 minutes depending on distance and preparation time.',
              ),
              _bulletPoint(
                'Actual delivery time may vary due to traffic, rider availability, or high order volume.',
              ),
              _bulletPoint(
                'Streat Eats is not liable for delays caused by factors outside our control (e.g. traffic jams, bad weather).',
              ),
              const SizedBox(height: 14),
              _legalHeading('4. Delivery OTP Confirmation'),
              const SizedBox(height: 6),
              const Text(
                'To ensure secure delivery, every order uses an OTP-based confirmation system:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              _bulletPoint(
                'A 4-digit OTP is sent to your registered email when the rider accepts your order.',
              ),
              _bulletPoint(
                'The rider must enter this OTP to mark your order as delivered.',
              ),
              _bulletPoint(
                'Do NOT share your OTP with anyone other than the Streat Eats rider.',
              ),
              _bulletPoint(
                'If you share the OTP and the order is marked delivered without actual delivery, Streat Eats is not liable.',
              ),
              _bulletPoint(
                'If the rider cannot reach you, they will call on your registered number. After 2 unanswered attempts, the order may be cancelled.',
              ),
              const SizedBox(height: 14),
              _legalHeading('5. Rider Conduct'),
              const SizedBox(height: 6),
              _bulletPoint(
                'All riders are verified and approved by the Streat Eats admin before they can deliver.',
              ),
              _bulletPoint(
                'Riders are required to call you before arriving at your location.',
              ),
              _bulletPoint(
                'Riders carry a cash float for vendor payment — you only pay them the total shown at checkout.',
              ),
              _bulletPoint(
                'If a rider behaves inappropriately, report immediately on Instagram @streateats.app.',
              ),
              const SizedBox(height: 14),
              _legalHeading('6. Failed Deliveries'),
              const SizedBox(height: 6),
              _bulletPoint(
                'If delivery fails due to incorrect address provided by the customer, the order will be marked as failed and no refund will be issued.',
              ),
              _bulletPoint(
                'If delivery fails due to our rider\'s fault, a full credit will be issued for your next order.',
              ),
              _bulletPoint(
                'Three failed delivery attempts from your end may result in a temporary account block.',
              ),
              const SizedBox(height: 16),
              _dateFooter('Last updated: May 11, 2026'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Instagram ─────────────────────────────────────────────────
  Future<void> _openInstagram() async {
    final appUrl = Uri.parse('instagram://user?username=streateats.app');
    final webUrl = Uri.parse('https://www.instagram.com/streateats.app');
    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ── Email Contact ─────────────────────────────────────────
  Future<void> _openEmail() async {
    final emailUrl = Uri.parse(
      'mailto:connect.streateats@gmail.com?subject=Streat Eats App Support',
    );
    if (await canLaunchUrl(emailUrl)) {
      await launchUrl(emailUrl);
    } else {
      _snack('Email app nahi mili', isError: true);
    }
  }

  // ── WhatsApp ──────────────────────────────────────────────
  Future<void> _openWhatsApp() async {
    const phone = '918630140017'; // ⚠️ Apna number daalo bina + ke
    const message = 'Hi Streat Eats!';
    final encoded = Uri.encodeComponent(message);
    final waApp = Uri.parse('whatsapp://send?phone=$phone&text=$encoded');
    final waWeb = Uri.parse('https://wa.me/$phone?text=$encoded');

    if (await canLaunchUrl(waApp)) {
      await launchUrl(waApp);
    } else {
      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?', style: AppStyles.sectionHeader),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<CartProvider>().clearCartOnLogout();
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
        _snack('Logout failed, please try again', isError: true);
      }
    }
  }

  // ── Set Password Section (Google Users) ──────────────────────
  Widget _buildSetPasswordSection(Color themeColor) {
    if (!_authService.isGoogleUser) return const SizedBox.shrink();
    final hasPassword = _authService.currentUserHasPassword;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPassword
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.primary.withOpacity(0.3),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasPassword
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasPassword
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: hasPassword
                          ? AppColors.success
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPassword ? 'Change Password' : 'Set Password',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasPassword
                              ? 'You can login with both Google and email-password'
                              : 'Login with email+password in addition to Google',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        if (!hasPassword) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Recommended',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: hasPassword ? AppColors.success : AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Login Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login to view your profile, orders and more.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Login / Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Poppins',
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

    final userProvider = context.watch<UserProvider>();
    final userData = userProvider.userData;
    final name = userData?['full_name'] as String? ?? 'User';
    final phone = userData?['phone'] as String? ?? '';
    final area = userData?['area'] as String? ?? '';
    final avatarUrl = userData?['avatar_url'] as String?;
    final themeColor = userProvider.themeColor;
    final savedAddress = userData?['delivery_address'] as String? ?? '';
    final savedLandmark = userData?['delivery_landmark'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isDeletingAccount
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.error),
                  SizedBox(height: 16),
                  Text(
                    'Deleting your account...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Avatar + Name Card ────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: themeColor,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _defaultAvatar(name),
                                        )
                                      : _defaultAvatar(name),
                                ),
                              ),
                              if (_isUploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _isUploadingPhoto
                                        ? AppColors.textMuted
                                        : themeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              // ── Phone Number Display ──────────
                              const SizedBox(height: 4),
                              if (phone.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+91 $phone',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                GestureDetector(
                                  onTap: () => _showEditProfileDialog(
                                    context,
                                    name,
                                    area,
                                    phone,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          color: AppColors.error,
                                          size: 12,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Add phone number',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (area.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      area,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(
                            context,
                            name,
                            area,
                            phone,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: themeColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Delivery Address Card ─────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.home_rounded,
                                color: themeColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Address',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Auto-filled at checkout',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              // REPLACE:
                              onTap: () async {
                                final result =
                                    await Navigator.push<PickedLocationResult>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddressSelectionScreen(
                                          currentLat:
                                              userData?['last_lat'] != null
                                              ? (userData!['last_lat'] as num)
                                                    .toDouble()
                                              : null,
                                          currentLng:
                                              userData?['last_lng'] != null
                                              ? (userData!['last_lng'] as num)
                                                    .toDouble()
                                              : null,
                                        ),
                                      ),
                                    );
                                if (result != null && mounted) {
                                  try {
                                    final userId =
                                        _supabase.auth.currentUser?.id;
                                    if (userId == null) return;
                                    final parts = result.address.split(',');
                                    final address = parts.first.trim();
                                    final landmark = parts.length > 1
                                        ? parts.sublist(1).join(',').trim()
                                        : '';
                                    await _supabase
                                        .from('users')
                                        .update({
                                          'delivery_address': result.address,
                                          'delivery_landmark': '',
                                          'last_lat': result.lat,
                                          'last_lng': result.lng,
                                        })
                                        .eq('id', userId);
                                    if (mounted) {
                                      await context
                                          .read<UserProvider>()
                                          .fetchUserData();
                                      _snack('Delivery address updated! 📍');
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      _snack('Save failed.', isError: true);
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  savedAddress.isEmpty
                                      ? Icons.add_rounded
                                      : Icons.edit_outlined,
                                  color: themeColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (savedAddress.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: themeColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        savedAddress,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (savedLandmark.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.flag_outlined,
                                        color: AppColors.textMuted,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          savedLandmark,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            // REPLACE:
                            onTap: () async {
                              final result =
                                  await Navigator.push<PickedLocationResult>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddressSelectionScreen(
                                        currentLat:
                                            userData?['last_lat'] != null
                                            ? (userData!['last_lat'] as num)
                                                  .toDouble()
                                            : null,
                                        currentLng:
                                            userData?['last_lng'] != null
                                            ? (userData!['last_lng'] as num)
                                                  .toDouble()
                                            : null,
                                      ),
                                    ),
                                  );
                              if (result != null && mounted) {
                                try {
                                  final userId = _supabase.auth.currentUser?.id;
                                  if (userId == null) return;
                                  await _supabase
                                      .from('users')
                                      .update({
                                        'delivery_address': result.address,
                                        'delivery_landmark': '',
                                        'last_lat': result.lat,
                                        'last_lng': result.lng,
                                      })
                                      .eq('id', userId);
                                  if (mounted) {
                                    await context
                                        .read<UserProvider>()
                                        .fetchUserData();
                                    _snack('Delivery address updated! 📍');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    _snack('Save failed.', isError: true);
                                  }
                                }
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: themeColor.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_location_alt_outlined,
                                    color: themeColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add delivery address',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: themeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Set Password (Google Users) ───────────────
                  _buildSetPasswordSection(themeColor),

                  // ── Account Section ───────────────────────────
                  _sectionCard(
                    children: [
                      Consumer<CartProvider>(
                        builder: (context, cart, _) => _menuItemWithBadge(
                          icon: Icons.shopping_bag_outlined,
                          label: 'My Cart',
                          themeColor: themeColor,
                          badge: cart.totalItems,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          ),
                        ),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'My Orders',
                        themeColor: themeColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'Feed Street Dogs 🐾',
                        themeColor: const Color(0xFFFF6B2B),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DonationScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── App Info Section ──────────────────────────────────────
                  _sectionCard(
                    children: [
                      _menuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'About Streat Eats',
                        themeColor: themeColor,
                        onTap: () => _showAboutDialog(context),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.star_rounded,
                        label: 'Rate & Review ⭐',
                        themeColor: const Color(0xFFFFD700), // Gold color
                        onTap: () => _showRatingDialog(context),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.photo_camera_outlined,
                        label: 'Follow on Instagram',
                        themeColor: themeColor,
                        onTap: _openInstagram,
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.chat_rounded,
                        label: 'Contact on WhatsApp',
                        themeColor: const Color(0xFF25D366), // WhatsApp green
                        onTap: _openWhatsApp,
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.email_outlined,
                        label: 'Email: connect.streateats@gmail.com',
                        themeColor: themeColor,
                        onTap: _openEmail,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Legal Section ─────────────────────────────
                  _sectionCard(
                    children: [
                      _menuItem(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        themeColor: themeColor,
                        onTap: () => _showTermsDialog(context),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy Policy',
                        themeColor: themeColor,
                        onTap: () => _showPrivacyDialog(context),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Refund & Cancellation',
                        themeColor: themeColor,
                        onTap: () => _showRefundDialog(context),
                      ),
                      _divider(),
                      _menuItem(
                        icon: Icons.delivery_dining_rounded,
                        label: 'Delivery Policy',
                        themeColor: themeColor,
                        onTap: () => _showDeliveryPolicyDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Logout ────────────────────────────────────
                  _sectionCard(
                    children: [
                      _menuItem(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        themeColor: themeColor,
                        color: AppColors.error,
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ════════════════════════════════════════════════
                  // ── DELETE ACCOUNT BUTTON ────────────────────
                  // ════════════════════════════════════════════════
                  _sectionCard(
                    children: [
                      _menuItem(
                        icon: Icons.delete_forever_rounded,
                        label: 'Delete Account',
                        themeColor: themeColor,
                        color: AppColors.error,
                        onTap: () => _deleteAccount(context),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'Permanent',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Streat Eats v1.0.0 • Made with ❤️ in Haldwani',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Reusable Helper Widgets ───────────────────────────────────
  Widget _defaultAvatar(String name) => Container(
    color: AppColors.primary.withOpacity(0.1),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    ),
  );

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    style: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      color: AppColors.textPrimary,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: AppColors.textMuted,
      ),
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: AppColors.textMuted,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    validator: validator,
  );

  Widget _sectionCard({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: Column(children: children),
  );

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color themeColor,
    Color? color,
    Widget? trailing,
  }) {
    final iconColor = color ?? themeColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: AppColors.border),
  );

  Widget _legalHeading(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _bulletPoint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    ),
  );

  Widget _dateFooter(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: AppColors.textMuted,
      ),
      textAlign: TextAlign.center,
    ),
  );

  // REPLACE:
  Widget _menuItemWithBadge({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color themeColor,
    required int badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: themeColor, size: 18),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // REPLACE:
  Widget _aboutRow(String emoji, String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
