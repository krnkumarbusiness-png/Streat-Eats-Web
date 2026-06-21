// lib/screens/admin/admin_banner_screen.dart
// v3.0 — Fixed image banner save, header color picker added, size guide added

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/storage_service.dart';

class AdminBannerScreen extends StatefulWidget {
  const AdminBannerScreen({super.key});

  @override
  State<AdminBannerScreen> createState() => _AdminBannerScreenState();
}

class _AdminBannerScreenState extends State<AdminBannerScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  String _welcomeText = '';
  bool _isSavingTicker = false;
  late final TextEditingController _tickerCtrl;

  static const _bucket = 'street-eats-images';

  @override
  void initState() {
    super.initState();
    _tickerCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _tickerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadBanners(), _loadTickerText()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadBanners() async {
    try {
      final data = await _supabase
          .from('banners')
          .select()
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() => _banners = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (mounted) _snack('Load failed: $e', isError: true);
    }
  }

  Future<void> _loadTickerText() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('welcome_text')
          .limit(1)
          .maybeSingle();
      if (data != null && mounted) {
        _welcomeText = data['welcome_text'] as String? ?? '';
        _tickerCtrl.text = _welcomeText;
      }
    } catch (_) {}
  }

  Future<void> _saveTickerText() async {
    final text = _tickerCtrl.text.trim();
    if (text.isEmpty) {
      _snack('Text daalo!', isError: true);
      return;
    }
    setState(() => _isSavingTicker = true);
    try {
      final existing = await _supabase
          .from('app_settings')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('app_settings')
            .update({'welcome_text': text})
            .eq('id', existing['id']);
      } else {
        await _supabase.from('app_settings').insert({'welcome_text': text});
      }
      if (mounted) {
        setState(() => _welcomeText = text);
        _snack('Ticker text save ho gaya! ✅');
      }
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingTicker = false);
    }
  }

  Future<void> _toggleBanner(String bannerId, bool current) async {
    try {
      await _supabase
          .from('banners')
          .update({'is_active': !current})
          .eq('id', bannerId);
      await _loadBanners();
      _snack(!current ? 'Banner live ho gaya! ✅' : 'Banner band ho gaya');
    } catch (e) {
      _snack('Update failed: $e', isError: true);
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    try {
      await _supabase.from('banners').delete().eq('id', bannerId);
      await _loadBanners();
      _snack('Banner delete ho gaya');
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  Future<String?> _uploadBannerImage(File file) async {
    final storageService = StorageService();
    final url = await storageService.uploadImage(file, folder: 'banners');
    if (url == null) _snack('Image upload failed', isError: true);
    return url;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showBannerForm({Map<String, dynamic>? banner}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BannerFormPage(
          banner: banner,
          bucket: _bucket,
          bannerCount: _banners.length,
          supabase: _supabase,
          onSaved: () async {
            await _loadBanners();
            _snack(
              banner == null
                  ? 'Banner create ho gaya! ✅'
                  : 'Banner update ho gaya! ✅',
            );
          },
          onError: (e) => _snack(e, isError: true),
          uploadImage: _uploadBannerImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _banners.where((b) => b['is_active'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Home Banner', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBannerForm(),
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Banner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ✅ Size Guide Card — sabse upar
                _buildSizeGuideCard(),
                const SizedBox(height: 16),
                _buildTickerCard(),
                const SizedBox(height: 20),
                _buildInfoBar(activeCount),
                const SizedBox(height: 16),
                if (_banners.isEmpty)
                  _buildEmptyState()
                else
                  ...List.generate(
                    _banners.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildBannerCard(_banners[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  // ✅ NEW — Banner size guide
  Widget _buildSizeGuideCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.photo_size_select_actual_rounded,
                  color: AppColors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Banner Size Guide',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Text(
                  'READ BEFORE UPLOAD',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Image Banner specs
          _specRow(
            icon: '🖼️',
            label: 'Image Banner',
            color: AppColors.primary,
            specs: [
              'Size: 1080 × 420 px  (16:6.2 ratio)',
              'Format: JPG ya WebP preferred',
              'Max file size: 500 KB',
              'Auto compress hogi — original mat bhejna',
            ],
            tip:
                'Tip: Text image ke left ya center mein rakho — right side page dots se dhakti hai',
          ),
          const SizedBox(height: 10),
          // Text Banner color info
          _specRow(
            icon: '📝',
            label: 'Text Banner',
            color: const Color(0xFF7B1FA2),
            specs: [
              'Title: Max 35 characters (2 lines max)',
              'Subtitle: Max 20 characters',
              'Emoji: 1 emoji best lagta hai — bada dikha',
              'Bg Color: Hex code ya preset se chuno',
              'Header Color: Alag color ya same rakh sakte ho',
            ],
            tip:
                'Tip: Dark bg color pe white text clearly dikhta hai — light colors avoid karo',
          ),
        ],
      ),
    );
  }

  Widget _specRow({
    required String icon,
    required String label,
    required Color color,
    required List<String> specs,
    required String tip,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...specs.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.text_fields_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Ticker Text',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Home screen pe scroll karta hua text',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _tickerCtrl.text.isEmpty
                    ? 'Ghar Baithe Street Ka Swad 🛵  •  Fresh, Fast & Local 🔥'
                    : _tickerCtrl.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tickerCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText:
                  'e.g. Ghar Baithe Street Ka Swad 🛵  •  Fresh, Fast & Local 🔥',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSavingTicker ? null : _saveTickerText,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingTicker
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Ticker Text Save Karo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(int activeCount) {
    return Row(
      children: [
        _infoChip(
          'Total',
          '${_banners.length}',
          Icons.campaign_outlined,
          AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        _infoChip(
          'Live',
          '$activeCount',
          Icons.radio_button_checked_rounded,
          AppColors.success,
        ),
        const SizedBox(width: 10),
        _infoChip(
          'Inactive',
          '${_banners.length - activeCount}',
          Icons.radio_button_unchecked_rounded,
          AppColors.error,
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    final isActive = banner['is_active'] as bool? ?? false;
    final statusColor = isActive ? AppColors.success : AppColors.textMuted;
    final bannerType =
        (banner['banner_type'] as String?)?.toLowerCase() ?? 'text';
    final isImageBanner = bannerType == 'image';
    final hasImage =
        isImageBanner && (banner['image_url'] as String?)?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ Preview: image banner ya text banner
          hasImage
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Image.network(
                    banner['image_url'],
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder(),
                  ),
                )
              : isImageBanner && !hasImage
              ? _buildMissingImagePlaceholder()
              : _buildTextBannerPreview(
                  title: banner['title'] ?? '',
                  subtitle: banner['subtitle'] ?? '',
                  emoji: banner['emoji'] ?? '🎉',
                  emojiImageUrl: banner['emoji_image_url'] as String?,
                  bgColor: _parseColor(banner['bg_color'] as String?),
                  headerColor: _parseColor(banner['header_color'] as String?),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    isImageBanner ? '🖼️ Image' : '📝 Text',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? 'Live' : 'Inactive',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleBanner(banner['id'], isActive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.error.withOpacity(0.08)
                          : AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppColors.error.withOpacity(0.3)
                            : AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: isActive ? AppColors.error : AppColors.success,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Band Karo' : 'Live Karo',
                          style: TextStyle(
                            color: isActive
                                ? AppColors.error
                                : AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _iconBtn(
                  Icons.edit_outlined,
                  AppColors.primary,
                  () => _showBannerForm(banner: banner),
                ),
                const SizedBox(width: 8),
                _iconBtn(
                  Icons.delete_outline_rounded,
                  AppColors.error,
                  () => _confirmDelete(banner),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Missing image placeholder (image banner type but no URL)
  Widget _buildMissingImagePlaceholder() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white38, size: 28),
            SizedBox(height: 4),
            Text(
              'Image upload nahi hui',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  // ✅ UPDATED — header color bhi show karta hai preview mein
  Widget _buildTextBannerPreview({
    required String title,
    required String subtitle,
    required String emoji,
    String? emojiImageUrl,
    Color bgColor = AppColors.primary,
    Color? headerColor,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
  }) {
    final resolvedHeaderColor = headerColor ?? bgColor;
    final endColor = Color.fromARGB(
      bgColor.alpha,
      (bgColor.red + 40).clamp(0, 255),
      (bgColor.green + 20).clamp(0, 255),
      (bgColor.blue + 10).clamp(0, 255),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Column(
        children: [
          // ✅ Header strip with header color
          Container(
            width: double.infinity,
            height: 6,
            color: resolvedHeaderColor,
          ),
          // Banner body
          Container(
            width: double.infinity,
            height: 94,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgColor, endColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 48, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                subtitle.isEmpty
                                    ? 'SUBTITLE'
                                    : subtitle.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              title.isEmpty
                                  ? 'Banner Title Yahan Aayega'
                                  : title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: (emojiImageUrl != null && emojiImageUrl.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              emojiImageUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          )
                        : Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> banner) {
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
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Banner?', style: AppStyles.sectionHeader),
          ],
        ),
        content: const Text(
          'Ye banner permanently delete ho jaayega.',
          style: AppStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBanner(banner['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                Icons.campaign_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Koi Banner Nahi', style: AppStyles.sectionHeader),
            const SizedBox(height: 8),
            const Text(
              '+ New Banner se pehla banner banao\naur home screen pe live karo',
              style: AppStyles.bodyText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Banner Form Page
// ✅ Fixed: banner_type correctly save hota hai
// ✅ Fixed: edit mein is_active preserve hota hai
// ✅ New: Header color picker added
// ════════════════════════════════════════════════════════════════

class _BannerFormPage extends StatefulWidget {
  final Map<String, dynamic>? banner;
  final String bucket;
  final int bannerCount;
  final SupabaseClient supabase;
  final VoidCallback onSaved;
  final Function(String) onError;
  final Future<String?> Function(File) uploadImage;

  const _BannerFormPage({
    required this.banner,
    required this.bucket,
    required this.bannerCount,
    required this.supabase,
    required this.onSaved,
    required this.onError,
    required this.uploadImage,
  });

  @override
  State<_BannerFormPage> createState() => _BannerFormPageState();
}

class _BannerFormPageState extends State<_BannerFormPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _bgHexCtrl;
  late final TextEditingController _headerHexCtrl; // ✅ NEW

  String _bannerType = 'text';
  String _selectedEmoji = '🎉';

  File? _emojiImageFile;
  String? _existingEmojiImageUrl;
  bool _useEmojiImage = false;

  // ✅ Bg color
  Color _selectedBgColor = const Color(0xFFFF6B2B);
  String _customBgHex = 'FF6B2B';

  // ✅ NEW — Header color (top strip color jo home screen ke background pe dikh
  Color _selectedHeaderColor = const Color(0xFFFF6B2B);
  String _customHeaderHex = 'FF6B2B';
  bool _useCustomHeaderColor = false; // false = same as bg color

  File? _selectedImageFile;
  String? _existingImageUrl;
  bool _isSaving = false;

  // Preset colors
  static const List<_PresetColor> _presetColors = [
    _PresetColor('Orange', Color(0xFFFF6B2B)),
    _PresetColor('Deep Red', Color(0xFFE53935)),
    _PresetColor('Purple', Color(0xFF7B1FA2)),
    _PresetColor('Indigo', Color(0xFF3949AB)),
    _PresetColor('Blue', Color(0xFF1E88E5)),
    _PresetColor('Teal', Color(0xFF00897B)),
    _PresetColor('Green', Color(0xFF43A047)),
    _PresetColor('Dark Navy', Color(0xFF1A1A2E)),
    _PresetColor('Charcoal', Color(0xFF37474F)),
    _PresetColor('Brown', Color(0xFF6D4C41)),
    _PresetColor('Pink', Color(0xFFD81B60)),
    _PresetColor('Gold', Color(0xFFD97706)),
  ];

  final List<String> _emojiOptions = [
    '🎉',
    '🛵',
    '🔥',
    '⚡',
    '🎊',
    '💥',
    '🥳',
    '🍔',
    '🥟',
    '🍕',
    '🎁',
    '💯',
    '🚀',
    '⭐',
    '🌟',
    '💫',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    _titleCtrl = TextEditingController(text: b?['title'] ?? '');
    _subtitleCtrl = TextEditingController(text: b?['subtitle'] ?? '');
    _selectedEmoji = b?['emoji'] ?? '🎉';
    _existingImageUrl = b?['image_url'];
    _existingEmojiImageUrl = b?['emoji_image_url'] as String?;
    _useEmojiImage =
        _existingEmojiImageUrl != null && _existingEmojiImageUrl!.isNotEmpty;

    // ✅ banner_type from DB
    _bannerType = (b?['banner_type'] as String?)?.toLowerCase() ?? 'text';

    // If old record has image_url but no banner_type field — fallback
    if (b != null &&
        _bannerType != 'image' &&
        (_existingImageUrl?.isNotEmpty == true)) {
      _bannerType = 'image';
    }

    // Load bg color
    final savedBgHex = b?['bg_color'] as String?;
    if (savedBgHex != null && savedBgHex.isNotEmpty) {
      try {
        final cleaned = savedBgHex.replaceAll('#', '');
        _selectedBgColor = Color(int.parse('FF$cleaned', radix: 16));
        _customBgHex = cleaned.toUpperCase();
      } catch (_) {}
    }
    _bgHexCtrl = TextEditingController(text: _customBgHex);

    // ✅ Load header color
    final savedHeaderHex = b?['header_color'] as String?;
    if (savedHeaderHex != null && savedHeaderHex.isNotEmpty) {
      try {
        final cleaned = savedHeaderHex.replaceAll('#', '');
        _selectedHeaderColor = Color(int.parse('FF$cleaned', radix: 16));
        _customHeaderHex = cleaned.toUpperCase();
        _useCustomHeaderColor = true;
      } catch (_) {}
    } else {
      // Default: same as bg color
      _selectedHeaderColor = _selectedBgColor;
      _customHeaderHex = _customBgHex;
    }
    _headerHexCtrl = TextEditingController(text: _customHeaderHex);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _bgHexCtrl.dispose();
    _headerHexCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEmojiImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      final originalFile = File(picked.path);
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalFile.path,
        '${originalFile.parent.path}/emoji_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: 80,
        minWidth: 200,
        minHeight: 200,
        format: CompressFormat.jpeg,
      );
      if (mounted) {
        setState(() {
          _emojiImageFile = compressed != null
              ? File(compressed.path)
              : originalFile;
          _useEmojiImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image pick failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _uploadEmojiImage(File file) async {
    final storageService = StorageService();
    return await storageService.uploadImage(file, folder: 'banners');
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final originalFile = File(picked.path);
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalFile.path,
        '${originalFile.parent.path}/banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: 75,
        minWidth: 1080,
        minHeight: 420,
        format: CompressFormat.jpeg,
      );
      if (mounted) {
        setState(
          () => _selectedImageFile = compressed != null
              ? File(compressed.path)
              : originalFile,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image pick failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyBgHex(String val) {
    final cleaned = val.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      try {
        final color = Color(int.parse('FF$cleaned', radix: 16));
        setState(() {
          _selectedBgColor = color;
          _customBgHex = cleaned.toUpperCase();
          // Agar custom header nahi lagaya to bg ke saath sync karo
          if (!_useCustomHeaderColor) {
            _selectedHeaderColor = color;
            _customHeaderHex = cleaned.toUpperCase();
            _headerHexCtrl.text = cleaned.toUpperCase();
          }
        });
      } catch (_) {}
    }
  }

  void _applyHeaderHex(String val) {
    final cleaned = val.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      try {
        final color = Color(int.parse('FF$cleaned', radix: 16));
        setState(() {
          _selectedHeaderColor = color;
          _customHeaderHex = cleaned.toUpperCase();
          _useCustomHeaderColor = true;
        });
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    if (_bannerType == 'text' && _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title daalo!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_bannerType == 'image' &&
        _selectedImageFile == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image select karo!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Upload full banner image
    String? imageUrl = _existingImageUrl;
    if (_bannerType == 'image' && _selectedImageFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image upload ho rahi hai... ⏳'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      imageUrl = await widget.uploadImage(_selectedImageFile!);
    }

    // Upload emoji image
    String? emojiImageUrl = _existingEmojiImageUrl;
    if (_bannerType == 'text' && _useEmojiImage && _emojiImageFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Character image upload ho rahi hai...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      emojiImageUrl = await _uploadEmojiImage(_emojiImageFile!);
    }

    // Colors as hex strings
    final bgHex =
        '#${_selectedBgColor.value.toRadixString(16).substring(2).toUpperCase()}';
    final headerHex =
        '#${_selectedHeaderColor.value.toRadixString(16).substring(2).toUpperCase()}';

    // ✅ FIXED: banner_type explicitly set karo
    // ✅ FIXED: editing mein is_active preserve karo (naya create mein false)
    final data = {
      'title': _bannerType == 'text' ? _titleCtrl.text.trim() : '',
      'subtitle': _bannerType == 'text' ? _subtitleCtrl.text.trim() : '',
      'emoji': (_bannerType == 'text' && !_useEmojiImage) ? _selectedEmoji : '',
      'emoji_image_url': (_bannerType == 'text' && _useEmojiImage)
          ? emojiImageUrl
          : null,
      'bg_color': _bannerType == 'text' ? bgHex : null,
      'header_color': _bannerType == 'text' ? headerHex : null, // ✅ NEW field
      'theme_color': bgHex, // home screen dynamic bg ke liye
      'image_url': _bannerType == 'image' ? imageUrl : null,
      'banner_type': _bannerType, // ✅ CRITICAL — ye pehle save nahi ho raha tha
      'sort_order': widget.banner?['sort_order'] ?? widget.bannerCount,
      // ✅ FIXED: naya banner = false, editing = existing value rakho
      if (widget.banner == null) 'is_active': false,
    };

    try {
      if (widget.banner == null) {
        await widget.supabase.from('banners').insert(data);
      } else {
        await widget.supabase
            .from('banners')
            .update(data)
            .eq('id', widget.banner!['id']);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      widget.onError('Save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.banner == null ? 'New Banner' : 'Edit Banner',
          style: AppStyles.screenTitle,
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner Type Toggle ────────────────────────────
            _lbl('Banner Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeChip(label: '📝 Text Banner', value: 'text'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _typeChip(label: '🖼️ Image Banner', value: 'image'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ════════════════════════════════════════════════════
            // IMAGE BANNER SECTION
            // ════════════════════════════════════════════════════
            if (_bannerType == 'image') ...[
              // ✅ Size reminder
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Text('📐', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended Size: 1080 × 420 px',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'JPG/WebP • Max 500KB • 16:6.2 ratio',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _lbl('Banner Image'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedImageFile != null
                          ? AppColors.primary
                          : AppColors.border,
                      width: _selectedImageFile != null ? 2 : 1.5,
                    ),
                  ),
                  child: _selectedImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedImageFile = null),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(15),
                                    ),
                                  ),
                                  child: const Text(
                                    '📷 Tap to change',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : (_existingImageUrl?.isNotEmpty == true)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                _existingImageUrl!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(15),
                                    ),
                                  ),
                                  child: const Text(
                                    '📷 Tap to change image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Banner image select karo',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '1080×420px • Auto compress hogi',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],

            // ════════════════════════════════════════════════════
            // TEXT BANNER SECTION
            // ════════════════════════════════════════════════════
            if (_bannerType == 'text') ...[
              // Live Preview
              _lbl('Live Preview'),
              const SizedBox(height: 8),
              _buildPreview(),
              const SizedBox(height: 20),

              // Title
              _lbl('Banner Title  (max 35 chars)'),
              const SizedBox(height: 8),
              _field(
                _titleCtrl,
                'e.g. Free Delivery On Every Order! 🎉',
                Icons.title_rounded,
                maxLength: 35,
              ),
              const SizedBox(height: 12),

              // Subtitle
              _lbl('Subtitle / Tag  (max 20 chars)'),
              const SizedBox(height: 8),
              _field(
                _subtitleCtrl,
                "e.g. Today's Special 🛵",
                Icons.subtitles_outlined,
                maxLength: 20,
              ),
              const SizedBox(height: 20),

              // ── Background Color ────────────────────────────
              _lbl('Background Color'),
              const SizedBox(height: 4),
              const Text(
                'Banner ka main background color',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetColors.map((pc) {
                  final isSelected = _selectedBgColor.value == pc.color.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBgColor = pc.color;
                        _customBgHex = pc.color.value
                            .toRadixString(16)
                            .substring(2)
                            .toUpperCase();
                        _bgHexCtrl.text = _customBgHex;
                        if (!_useCustomHeaderColor) {
                          _selectedHeaderColor = pc.color;
                          _customHeaderHex = _customBgHex;
                          _headerHexCtrl.text = _customBgHex;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: pc.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: pc.color.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _colorHexInput(
                label: 'Custom Bg Hex',
                previewColor: _selectedBgColor,
                ctrl: _bgHexCtrl,
                onChanged: _applyBgHex,
              ),
              const SizedBox(height: 20),

              // ✅ NEW — Header Color Section
              _lbl('Header Color (Home Screen Background)'),
              const SizedBox(height: 4),
              const Text(
                'Ye color home screen ka background gradient set karta hai jab ye banner active hota hai',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 10),
              // Toggle: Same as bg / Custom
              Row(
                children: [
                  Expanded(
                    child: _headerChip(
                      label: '🔗 Same as Bg Color',
                      isCustom: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _headerChip(
                      label: '🎨 Custom Header Color',
                      isCustom: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_useCustomHeaderColor) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _presetColors.map((pc) {
                    final isSelected =
                        _selectedHeaderColor.value == pc.color.value;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedHeaderColor = pc.color;
                          _customHeaderHex = pc.color.value
                              .toRadixString(16)
                              .substring(2)
                              .toUpperCase();
                          _headerHexCtrl.text = _customHeaderHex;
                          _useCustomHeaderColor = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: pc.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pc.color.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _colorHexInput(
                  label: 'Custom Header Hex',
                  previewColor: _selectedHeaderColor,
                  ctrl: _headerHexCtrl,
                  onChanged: _applyHeaderHex,
                ),
              ] else ...[
                // Preview showing same as bg
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Header Color = Background Color',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              '#$_customBgHex',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.link_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Right Side: Emoji OR Image ──────────────────
              _lbl('Right Side — Emoji ya Image?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _sideChip(label: '😀 Emoji', useImage: false),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sideChip(
                      label: '🖼️ Character / Model',
                      useImage: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!_useEmojiImage) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiOptions.map((e) {
                    final isSelected = _selectedEmoji == e;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              if (_useEmojiImage) ...[
                GestureDetector(
                  onTap: _pickEmojiImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            (_emojiImageFile != null ||
                                _existingEmojiImageUrl != null)
                            ? AppColors.primary
                            : AppColors.border,
                        width:
                            (_emojiImageFile != null ||
                                _existingEmojiImageUrl != null)
                            ? 2
                            : 1.5,
                      ),
                    ),
                    child: _emojiImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  _emojiImageFile!,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _emojiImageFile = null;
                                      _existingEmojiImageUrl = null;
                                      _useEmojiImage = false;
                                    }),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      '📷 Tap to change',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : (_existingEmojiImageUrl?.isNotEmpty == true)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  _existingEmojiImageUrl!,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      '📷 Tap to change',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_pin_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Character / Model image chunno',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'PNG with transparent bg best lagega',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),

            // ── Save Button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Save ho raha hai...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.banner == null
                            ? 'Banner Create Karo ✅'
                            : 'Banner Update Karo ✅',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Live Preview ──────────────────────────────────────────
  Widget _buildPreview() {
    final endColor = Color.fromARGB(
      _selectedBgColor.alpha,
      (_selectedBgColor.red + 40).clamp(0, 255),
      (_selectedBgColor.green + 20).clamp(0, 255),
      (_selectedBgColor.blue + 10).clamp(0, 255),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          // ✅ Header color strip preview
          Container(
            width: double.infinity,
            height: 6,
            color: _useCustomHeaderColor
                ? _selectedHeaderColor
                : _selectedBgColor,
          ),
          // Banner body
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_selectedBgColor, endColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 60, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _subtitleCtrl.text.isEmpty
                              ? 'SUBTITLE'
                              : _subtitleCtrl.text.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _titleCtrl.text.isEmpty
                            ? 'Banner Title Yahan Aayega'
                            : _titleCtrl.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _useEmojiImage
                        ? (_emojiImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _emojiImageFile!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : _existingEmojiImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _existingEmojiImageUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_pin_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ))
                        : Text(
                            _selectedEmoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Reusable hex color input
  Widget _colorHexInput({
    required String label,
    required Color previewColor,
    required TextEditingController ctrl,
    required void Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: previewColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '#',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
              ],
              onChanged: onChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontFamily: 'Poppins',
              ),
              decoration: const InputDecoration(
                hintText: 'FF6B2B',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip({required String label, required String value}) {
    final isSelected = _bannerType == value;
    return GestureDetector(
      onTap: () => setState(() => _bannerType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW — header color mode chip
  Widget _headerChip({required String label, required bool isCustom}) {
    final isSelected = _useCustomHeaderColor == isCustom;
    return GestureDetector(
      onTap: () {
        setState(() {
          _useCustomHeaderColor = isCustom;
          if (!isCustom) {
            // Reset to bg color
            _selectedHeaderColor = _selectedBgColor;
            _customHeaderHex = _customBgHex;
            _headerHexCtrl.text = _customBgHex;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _sideChip({required String label, required bool useImage}) {
    final isSelected = _useEmojiImage == useImage;
    return GestureDetector(
      onTap: () => setState(() => _useEmojiImage = useImage),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      fontFamily: 'Poppins',
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        counterStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontFamily: 'Poppins',
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ✅ Helper class for preset colors
class _PresetColor {
  final String name;
  final Color color;
  const _PresetColor(this.name, this.color);
}
