// lib/screens/admin/admin_vendors_screen.dart
// v2.4 — Price fields updated: "Our Price for 2" → "Avg Bill Per Person (₹)"
// ✅ No Zomato/Swiggy mention in UI — generic "other platforms"
// ✅ All previous features preserved exactly (badge, rating, chaupati, etc.)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/storage_service.dart';

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  bool _statsExpanded = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _timeSlots = [];
  String _morningShiftLabel = '10 AM – 1 PM';
  String _eveningShiftLabel = '5 PM – 9 PM';

  static const List<Map<String, String>> _badgeOptions = [
    {'label': 'None', 'value': ''},
    {'label': '👑 Legend', 'value': 'Legend'},
    {'label': '✨ New', 'value': 'New'},
    {'label': '🔥 Trending', 'value': 'Trending'},
    {'label': '⭐ Popular', 'value': 'Popular'},
    {'label': '💯 Top Rated', 'value': 'Top Rated'},
    {'label': '🏆 Premium', 'value': 'Premium'},
  ];

  final List<String> _defaultCategories = [
    'Momos',
    'Burger',
    'Chowmein',
    'Pizza',
    'Chaat',
    'Maggi',
    'Sandwich',
    'Shake',
    'Samosa',
  ];

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  List<Map<String, dynamic>> get _filteredVendors {
    if (_searchQuery.isEmpty) return _vendors;
    return _vendors.where((v) {
      final name = (v['name'] as String? ?? '').toLowerCase();
      final area = (v['area'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || area.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadVendors(), _loadShiftSettings()]);
  }

  Future<void> _loadShiftSettings() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('time_slots, is_timing_enabled')
          .limit(1)
          .maybeSingle();
      if (data == null) return;
      final slotsRaw = data['time_slots'];
      if (slotsRaw != null && (slotsRaw as List).isNotEmpty) {
        final slots = (slotsRaw)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .where((s) => s['enabled'] == true)
            .toList();
        if (mounted) {
          setState(() {
            _timeSlots = slots;
            // Morning slot — label build karo
            final morningSlots = slots.where((s) {
              final open = s['open'] as String? ?? '';
              final hour = int.tryParse(open.split(':')[0]) ?? 0;
              return hour < 14; // 14 se pehle = morning
            }).toList();
            final eveningSlots = slots.where((s) {
              final open = s['open'] as String? ?? '';
              final hour = int.tryParse(open.split(':')[0]) ?? 0;
              return hour >= 14; // 14 ke baad = evening
            }).toList();
            if (morningSlots.isNotEmpty) {
              final s = morningSlots.first;
              _morningShiftLabel =
                  '${_formatSlotTime(s['open'])} – ${_formatSlotTime(s['close'])}';
            }
            if (eveningSlots.isNotEmpty) {
              final s = eveningSlots.first;
              _eveningShiftLabel =
                  '${_formatSlotTime(s['open'])} – ${_formatSlotTime(s['close'])}';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Shift settings load error: $e');
    }
  }

  String _formatSlotTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      final tod = TimeOfDay(hour: hour, minute: min);
      final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final m = min.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    } catch (_) {
      return timeStr;
    }
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('vendors')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Load failed: $e', isError: true);
      }
    }
  }

  Future<void> _toggleVendorStatus(String vendorId, bool current) async {
    try {
      await _supabase
          .from('vendors')
          .update({'is_active': !current})
          .eq('id', vendorId);
      await _loadVendors();
    } catch (e) {
      if (mounted) _snack('Update failed: $e', isError: true);
    }
  }

  Future<void> _deleteVendor(String vendorId) async {
    try {
      await _supabase.from('vendors').delete().eq('id', vendorId);
      await _loadVendors();
      if (mounted) _snack('Vendor deleted');
    } catch (e) {
      if (mounted) _snack('Delete failed: $e', isError: true);
    }
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

  List<String> _parseCategories(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return [];
    return raw
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<File?> _pickAndCompressImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final originalFile = File(picked.path);
    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.path,
      '${originalFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 70,
      minWidth: 600,
      minHeight: 400,
      format: CompressFormat.jpeg,
    );
    return compressed != null ? File(compressed.path) : originalFile;
  }

  Future<String?> _uploadImage(File imageFile, String folder) async {
    final storageService = StorageService();
    final url = await storageService.uploadImage(imageFile, folder: folder);
    if (url == null) _snack('Image upload failed', isError: true);
    return url;
  }

  Future<void> _fetchCurrentLocation(
    TextEditingController latCtrl,
    TextEditingController lngCtrl,
    StateSetter setModal,
  ) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _snack('Location service is off!', isError: true);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _snack('Location permission denied!', isError: true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _snack('Permission permanently denied', isError: true);
      return;
    }
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setModal(() {
        latCtrl.text = pos.latitude.toStringAsFixed(6);
        lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      _snack('Location fetched successfully!');
    } catch (e) {
      _snack('Location fetch failed: $e', isError: true);
    }
  }

  void _showVendorForm({Map<String, dynamic>? vendor}) {
    final nameCtrl = TextEditingController(text: vendor?['name'] ?? '');
    final areaCtrl = TextEditingController(text: vendor?['area'] ?? '');
    final latCtrl = TextEditingController(
      text: vendor?['latitude']?.toString() ?? '',
    );
    final lngCtrl = TextEditingController(
      text: vendor?['longitude']?.toString() ?? '',
    );
    final customCatCtrl = TextEditingController();
    final cuisineTypeCtrl = TextEditingController(
      text: vendor?['cuisine_type'] ?? '',
    );

    // ✅ UPDATED: "price_for_two" ab "Avg Bill Per Person" ke naam se dikhega
    final avgBillPerPersonCtrl = TextEditingController(
      text: vendor?['price_for_two']?.toString() ?? '',
    );

    // ✅ UPDATED: "other_platform_avg" ab "Other Platforms Avg" ke naam se dikhega
    final otherPlatformAvgCtrl = TextEditingController(
      text: vendor?['other_platform_avg']?.toString() ?? '',
    );

    final minOrderCtrl = TextEditingController(
      text: vendor?['min_order']?.toString() ?? '0',
    );
    final ratingCtrl = TextEditingController(
      text: vendor?['rating']?.toString() ?? '',
    );

    bool isRecommendedHome = vendor?['is_recommended_home'] as bool? ?? false;

    bool isFetchingLocation = false;
    bool isUploading = false;
    File? selectedImageFile;
    String? existingImageUrl = vendor?['image_url'];

    final List<String> selectedCategories = List<String>.from(
      _parseCategories(vendor?['category']),
    );
    final List<String> allChips = List<String>.from(_defaultCategories);
    for (final cat in selectedCategories) {
      if (!allChips.contains(cat)) allChips.add(cat);
    }

    String selectedVendorType = vendor?['vendor_type'] as String? ?? 'both';
    String selectedBusinessType =
        vendor?['business_type'] as String? ?? 'street_food';
    String selectedBadge = vendor?['vendor_badge'] as String? ?? '';
    bool isPremium = vendor?['is_premium'] as bool? ?? false;
    bool morningShiftActive = vendor?['morning_shift_active'] as bool? ?? false;
    bool eveningShiftActive = vendor?['evening_shift_active'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (_, setModal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
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
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      vendor == null ? 'Add Vendor' : 'Edit Vendor',
                      style: AppStyles.sectionHeader,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Shop Image
                const Text(
                  'Shop / Stall Photo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shown on vendor detail page',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final file = await _pickAndCompressImage();
                    if (file != null) setModal(() => selectedImageFile = file);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedImageFile != null
                            ? AppColors.primary
                            : AppColors.border,
                        width: selectedImageFile != null ? 2 : 1,
                      ),
                    ),
                    child: selectedImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  selectedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setModal(
                                      () => selectedImageFile = null,
                                    ),
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
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  existingImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Tap to change photo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.primary.withOpacity(0.5),
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add shop photo',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Auto compressed before upload',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                _adminField(nameCtrl, 'Vendor Name', Icons.storefront_outlined),
                const SizedBox(height: 12),
                _adminField(
                  areaCtrl,
                  'Area / Locality',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 20),

                // Vendor Badge
                _buildSectionLabel(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Vendor Badge',
                  subtitle:
                      'Home screen card pe dikhega — premium feeling deta hai',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _badgeOptions.map((badge) {
                    final isSelected = selectedBadge == badge['value'];
                    return GestureDetector(
                      onTap: () =>
                          setModal(() => selectedBadge = badge['value']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          badge['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Rating + Premium toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFD97706),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'RATING & PREMIUM',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ratingCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                              decoration: InputDecoration(
                                hintText: 'Rating (e.g. 4.2)',
                                hintStyle: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                                prefixIcon: const Icon(
                                  Icons.star_half_rounded,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
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
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModal(() => isPremium = !isPremium),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isPremium
                                      ? const Color(0xFFD97706).withOpacity(0.1)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isPremium
                                        ? const Color(0xFFD97706)
                                        : AppColors.border,
                                    width: isPremium ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      isPremium ? '👑' : '⬜',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Premium',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins',
                                        color: isPremium
                                            ? const Color(0xFFD97706)
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      isPremium ? 'ON' : 'OFF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Poppins',
                                        color: isPremium
                                            ? const Color(0xFFD97706)
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.textMuted,
                            size: 12,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rating = stars dikhenge card pe. Premium = "Premium Picks" section mein aayega.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Business Type
                const Text(
                  'Business Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Is this a street stall or a restaurant?',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _businessTypeChip(
                      label: '🥟 Street Food',
                      value: 'street_food',
                      selected: selectedBusinessType,
                      onTap: () =>
                          setModal(() => selectedBusinessType = 'street_food'),
                    ),
                    const SizedBox(width: 10),
                    _businessTypeChip(
                      label: '🍽️ Restaurant',
                      value: 'restaurant',
                      selected: selectedBusinessType,
                      onTap: () =>
                          setModal(() => selectedBusinessType = 'restaurant'),
                    ),
                    const SizedBox(width: 10),
                    _businessTypeChip(
                      label: '🍬 Sweets Shop',
                      value: 'sweets',
                      selected: selectedBusinessType,
                      onTap: () =>
                          setModal(() => selectedBusinessType = 'sweets'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 13,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedBusinessType == 'street_food'
                              ? 'This vendor will appear in the Street Food tab.'
                              : selectedBusinessType == 'sweets'
                              ? 'This vendor will appear in the Sweets & Mithai tab.'
                              : 'This vendor will appear in the Restaurants tab with price comparison.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ UPDATED: Restaurant-only Fields — no Zomato/Swiggy mention
                if (selectedBusinessType == 'restaurant') ...[
                  // Section header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withOpacity(0.2),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              color: Color(0xFF2563EB),
                              size: 15,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'RESTAURANT DETAILS',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ye fields app pe price comparison ke liye use honge',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _adminField(
                    cuisineTypeCtrl,
                    'Cuisine Type (e.g. North Indian, Chinese)',
                    Icons.restaurant_menu_outlined,
                  ),
                  const SizedBox(height: 10),

                  // ✅ UPDATED: "Avg Bill Per Person" instead of "Our Price for 2"
                  _adminField(
                    avgBillPerPersonCtrl,
                    'Avg Bill Per Person on Street Eats (₹)',
                    Icons.person_outline_rounded,
                    keyboardType: TextInputType.number,
                    helperText:
                        'Humara platform pe ek banda kitna kharch karta hai',
                  ),
                  const SizedBox(height: 10),

                  // ✅ UPDATED: "Other Platforms Avg" — no Zomato/Swiggy mention
                  _adminField(
                    otherPlatformAvgCtrl,
                    'Avg Bill Per Person on Other Platforms (₹)',
                    Icons.compare_arrows_rounded,
                    keyboardType: TextInputType.number,
                    helperText:
                        'Doosre platforms pe same restaurant pe ek banda kitna deta hai',
                  ),
                  const SizedBox(height: 10),
                  _adminField(
                    minOrderCtrl,
                    'Min Order Amount (₹)',
                    Icons.shopping_bag_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Live savings preview
                  Builder(
                    builder: (_) {
                      final ours = int.tryParse(avgBillPerPersonCtrl.text) ?? 0;
                      final theirs =
                          int.tryParse(otherPlatformAvgCtrl.text) ?? 0;
                      if (theirs <= 0 || ours <= 0 || ours >= theirs) {
                        return const SizedBox.shrink();
                      }
                      final savingsPct = (((theirs - ours) / theirs) * 100)
                          .round();
                      final savingsAmt = theirs - ours;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              color: AppColors.success,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer saves $savingsPct% (₹$savingsAmt per person)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const Text(
                                    'vs other food delivery platforms',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // ✅ NAYA — Sweets Shop fields
                if (selectedBusinessType == 'sweets') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD97706).withOpacity(0.2),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              color: Color(0xFFD97706),
                              size: 15,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'SWEETS SHOP DETAILS',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mithai, Cake, Ice Cream — sab types ke liye',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _adminField(
                    cuisineTypeCtrl,
                    'Shop Type (e.g. Mithai, Cake Shop, Ice Cream)',
                    Icons.storefront_outlined,
                    helperText: 'Kya speciality hai is shop ki',
                  ),
                  const SizedBox(height: 10),
                  _adminField(
                    minOrderCtrl,
                    'Min Order Amount (₹)',
                    Icons.shopping_bag_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                ],

                // Vendor Type
                const Text(
                  'Vendor Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What food does this vendor serve?',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _vendorTypeChip(
                      label: '🥦 Veg Only',
                      value: 'veg',
                      selected: selectedVendorType,
                      color: AppColors.success,
                      onTap: () => setModal(() => selectedVendorType = 'veg'),
                    ),
                    const SizedBox(width: 8),
                    _vendorTypeChip(
                      label: '🍗 Non-Veg',
                      value: 'non_veg',
                      selected: selectedVendorType,
                      color: AppColors.error,
                      onTap: () =>
                          setModal(() => selectedVendorType = 'non_veg'),
                    ),
                    const SizedBox(width: 8),
                    _vendorTypeChip(
                      label: '🍽️ Both',
                      value: 'both',
                      selected: selectedVendorType,
                      color: AppColors.primary,
                      onTap: () => setModal(() => selectedVendorType = 'both'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _vendorTypeColor(
                      selectedVendorType,
                    ).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _vendorTypeColor(
                        selectedVendorType,
                      ).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _vendorTypeColor(selectedVendorType),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _vendorTypeInfo(selectedVendorType),
                          style: TextStyle(
                            fontSize: 11,
                            color: _vendorTypeColor(selectedVendorType),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Show on Home Screen toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRecommendedHome
                        ? const Color(0xFF2563EB).withOpacity(0.04)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRecommendedHome
                          ? const Color(0xFF2563EB).withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Show on Home Screen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isRecommendedHome
                                  ? 'Appears in "Recommended Restaurants" section'
                                  : 'Not shown on home screen',
                              style: TextStyle(
                                fontSize: 11,
                                color: isRecommendedHome
                                    ? const Color(0xFF2563EB)
                                    : AppColors.textMuted,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setModal(
                          () => isRecommendedHome = !isRecommendedHome,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 52,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isRecommendedHome
                                ? const Color(0xFF2563EB)
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                left: isRecommendedHome ? 26 : 2,
                                top: 2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Shift Timing
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'SHIFT AVAILABILITY',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kis shift mein ye vendor available hai?',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Morning Shift Toggle
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: morningShiftActive
                                  ? const Color(0xFFF59E0B).withOpacity(0.15)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: morningShiftActive
                                    ? const Color(0xFFF59E0B)
                                    : AppColors.border,
                              ),
                            ),
                            child: const Center(
                              child: Text('🌅', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Morning Shift',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  morningShiftActive
                                      ? '$_morningShiftLabel active'
                                      : 'Not available in morning',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: morningShiftActive
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModal(
                              () => morningShiftActive = !morningShiftActive,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 52,
                              height: 28,
                              decoration: BoxDecoration(
                                color: morningShiftActive
                                    ? const Color(0xFFF59E0B)
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    left: morningShiftActive ? 26 : 2,
                                    top: 2,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Container(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Evening Shift Toggle
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: eveningShiftActive
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: eveningShiftActive
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: const Center(
                              child: Text('🌆', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Evening Shift',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  eveningShiftActive
                                      ? '$_eveningShiftLabel active'
                                      : 'Not available in evening',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: eveningShiftActive
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModal(
                              () => eveningShiftActive = !eveningShiftActive,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 52,
                              height: 28,
                              decoration: BoxDecoration(
                                color: eveningShiftActive
                                    ? AppColors.primary
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    left: eveningShiftActive ? 26 : 2,
                                    top: 2,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.warning,
                              size: 13,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                !morningShiftActive && !eveningShiftActive
                                    ? '⚠️ Koi bhi shift active nahi — vendor app pe nahi dikhega!'
                                    : morningShiftActive && eveningShiftActive
                                    ? 'Vendor dono shifts mein dikhega (10 AM–1 PM & 5 PM–9 PM)'
                                    : morningShiftActive
                                    ? 'Vendor sirf subah dikhega (10 AM–1 PM)'
                                    : 'Vendor sirf shaam ko dikhega (5 PM–9 PM)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      !morningShiftActive && !eveningShiftActive
                                      ? AppColors.error
                                      : AppColors.warning,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Location
                const Row(
                  children: [
                    Text(
                      'Vendor Location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(auto-fetch or enter manually)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: isFetchingLocation
                      ? null
                      : () async {
                          setModal(() => isFetchingLocation = true);
                          await _fetchCurrentLocation(
                            latCtrl,
                            lngCtrl,
                            setModal,
                          );
                          setModal(() => isFetchingLocation = false);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(
                          isFetchingLocation ? 0.2 : 0.35,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isFetchingLocation)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isFetchingLocation
                              ? 'Fetching location...'
                              : 'Auto-Fetch Current Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: isFetchingLocation
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR MANUALLY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _adminField(
                        latCtrl,
                        'Latitude',
                        Icons.my_location_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _adminField(
                        lngCtrl,
                        'Longitude',
                        Icons.explore_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Categories
                Row(
                  children: [
                    const Text(
                      'Food Categories',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectedCategories.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${selectedCategories.length} selected',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select all categories this vendor sells',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allChips.map((cat) {
                    final isSelected = selectedCategories.contains(cat);
                    final isCustom = !_defaultCategories.contains(cat);
                    return GestureDetector(
                      onTap: () {
                        setModal(() {
                          if (isSelected) {
                            selectedCategories.remove(cat);
                          } else {
                            selectedCategories.add(cat);
                          }
                        });
                      },
                      onLongPress: isCustom
                          ? () {
                              setModal(() {
                                allChips.remove(cat);
                                selectedCategories.remove(cat);
                              });
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : isCustom
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.border,
                            width: isSelected || isCustom ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCustom && !isSelected) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: AppColors.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: isSelected
                                    ? Colors.white
                                    : isCustom
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '+ Add Custom Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Type a new category not in the list above',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customCatCtrl,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'e.g. Paratha, Rolls, Dosa...',
                                hintStyle: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _addCustomCategory(
                                customCatCtrl,
                                allChips,
                                selectedCategories,
                                setModal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _addCustomCategory(
                              customCatCtrl,
                              allChips,
                              selectedCategories,
                              setModal,
                            ),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selectedCategories.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Please select at least one category',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                areaCtrl.text.trim().isEmpty ||
                                latCtrl.text.trim().isEmpty ||
                                lngCtrl.text.trim().isEmpty) {
                              _snack(
                                'Please fill all required fields',
                                isError: true,
                              );
                              return;
                            }
                            if (selectedCategories.isEmpty) {
                              _snack(
                                'Please select at least one category',
                                isError: true,
                              );
                              return;
                            }
                            if (selectedBusinessType == 'restaurant') {
                              if (avgBillPerPersonCtrl.text.trim().isEmpty ||
                                  otherPlatformAvgCtrl.text.trim().isEmpty) {
                                _snack(
                                  'Please fill price fields for restaurant',
                                  isError: true,
                                );
                                return;
                              }
                            }
                            setModal(() => isUploading = true);
                            String? imageUrl = existingImageUrl;
                            if (selectedImageFile != null) {
                              imageUrl = await _uploadImage(
                                selectedImageFile!,
                                'vendors',
                              );
                              if (imageUrl == null) {
                                setModal(() => isUploading = false);
                                return;
                              }
                            }
                            final data = {
                              'name': nameCtrl.text.trim(),
                              'area': areaCtrl.text.trim(),
                              'latitude': double.tryParse(latCtrl.text) ?? 0,
                              'longitude': double.tryParse(lngCtrl.text) ?? 0,
                              'category': selectedCategories.join(','),
                              'city': 'Haldwani',
                              'is_active': true,
                              'vendor_type': selectedVendorType,
                              'business_type': selectedBusinessType,
                              'cuisine_type':
                                  (selectedBusinessType == 'restaurant' ||
                                      selectedBusinessType == 'sweets')
                                  ? cuisineTypeCtrl.text.trim()
                                  : null,
                              // ✅ DB field same "price_for_two" — but now stores avg per person
                              'price_for_two':
                                  selectedBusinessType == 'restaurant'
                                  ? int.tryParse(avgBillPerPersonCtrl.text)
                                  : null,
                              'other_platform_avg':
                                  selectedBusinessType == 'restaurant'
                                  ? int.tryParse(otherPlatformAvgCtrl.text)
                                  : null,
                              'min_order': int.tryParse(minOrderCtrl.text) ?? 0,
                              'vendor_badge': selectedBadge.isEmpty
                                  ? null
                                  : selectedBadge,
                              'rating': double.tryParse(ratingCtrl.text),
                              'is_premium': isPremium,
                              'is_recommended_home': isRecommendedHome,
                              'morning_shift_active': morningShiftActive,
                              'evening_shift_active': eveningShiftActive,
                              if (imageUrl != null) 'image_url': imageUrl,
                            };
                            try {
                              if (vendor == null) {
                                await _supabase.from('vendors').insert(data);
                              } else {
                                await _supabase
                                    .from('vendors')
                                    .update(data)
                                    .eq('id', vendor['id']);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadAll();
                              _snack(
                                vendor == null
                                    ? 'Vendor added successfully!'
                                    : 'Vendor updated successfully!',
                              );
                            } catch (e) {
                              setModal(() => isUploading = false);
                              _snack('Save failed: $e', isError: true);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Saving...',
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
                            vendor == null ? 'Add Vendor' : 'Update Vendor',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ────────────────────────────────────────

  Widget _buildSectionLabel({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _businessTypeChip({
    required String label,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label.split(' ')[0], style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label.split(' ').skip(1).join(' '),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vendorTypeChip({
    required String label,
    required String value,
    required String selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label.split(' ')[0], style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(
                label.split(' ').skip(1).join(' '),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _vendorTypeColor(String type) {
    switch (type) {
      case 'veg':
        return AppColors.success;
      case 'non_veg':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _vendorTypeInfo(String type) {
    switch (type) {
      case 'veg':
        return 'This vendor will appear in veg mode only.';
      case 'non_veg':
        return 'This vendor will NOT appear in veg mode.';
      default:
        return 'This vendor appears in both veg and non-veg modes.';
    }
  }

  void _addCustomCategory(
    TextEditingController ctrl,
    List<String> allChips,
    List<String> selected,
    StateSetter setModal,
  ) {
    final trimmed = ctrl.text.trim();
    if (trimmed.isEmpty) return;
    final formatted =
        trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
    if (!allChips.contains(formatted)) {
      setModal(() {
        allChips.add(formatted);
        selected.add(formatted);
        ctrl.clear();
      });
    } else if (!selected.contains(formatted)) {
      setModal(() {
        selected.add(formatted);
        ctrl.clear();
      });
    } else {
      ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _vendors.where((v) => v['is_active'] == true).length;
    final streetFoodCount = _vendors
        .where((v) => (v['business_type'] ?? 'street_food') == 'street_food')
        .length;
    final restaurantCount = _vendors
        .where((v) => v['business_type'] == 'restaurant')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Vendors (${_vendors.length})',
          style: AppStyles.screenTitle,
        ),
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
        onPressed: () => _showVendorForm(),
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Vendor',
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
          : _vendors.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildStatsBar(activeCount, streetFoodCount, restaurantCount),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Vendor name search karo...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadAll,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _filteredVendors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _buildVendorCard(_filteredVendors[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsBar(
    int activeCount,
    int streetFoodCount,
    int restaurantCount,
  ) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _statsExpanded = !_statsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Stats — ${_vendors.length} vendors, $activeCount active',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _statsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  _statCard(
                    'Active',
                    '$activeCount',
                    Icons.check_circle_outline_rounded,
                    AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Street Food',
                    '$streetFoodCount',
                    Icons.storefront_rounded,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Restaurants',
                    '$restaurantCount',
                    Icons.restaurant_rounded,
                    AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _statCard(
                    'Inactive',
                    '${_vendors.length - activeCount}',
                    Icons.pause_circle_outline_rounded,
                    AppColors.error,
                  ),
                ],
              ),
            ),
            crossFadeState: _statsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          Container(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final isActive = vendor['is_active'] as bool? ?? false;
    final statusColor = isActive ? AppColors.success : AppColors.error;
    final categories = _parseCategories(vendor['category']);
    final shopImageUrl = vendor['image_url'] as String?;
    final vendorType = vendor['vendor_type'] as String? ?? 'both';
    final businessType = vendor['business_type'] as String? ?? 'street_food';
    final isRestaurant = businessType == 'restaurant';
    final vendorBadge = vendor['vendor_badge'] as String?;
    final rating = vendor['rating'];
    final isPremium = vendor['is_premium'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFD97706).withOpacity(0.4)
              : AppColors.border,
          width: isPremium ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (shopImageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    shopImageUrl,
                    width: double.infinity,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  if (vendorBadge != null && vendorBadge.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vendorBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  if (rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$rating',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: shopImageUrl == null
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.zero,
              border: Border(
                bottom: BorderSide(color: statusColor.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                if (shopImageUrl == null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        isRestaurant ? '🍽️' : '🥟',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vendor['name'] ?? '',
                              style: AppStyles.cardTitle,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFD97706,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFFD97706,
                                  ).withOpacity(0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Color(0xFFD97706),
                                    size: 10,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRestaurant
                                  ? const Color(0xFF2563EB).withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isRestaurant
                                    ? const Color(0xFF2563EB).withOpacity(0.3)
                                    : AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isRestaurant ? '🍽️ Restaurant' : '🥟 Street',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isRestaurant
                                    ? const Color(0xFF2563EB)
                                    : AppColors.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _vendorTypeColor(
                                vendorType,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _vendorTypeColor(
                                  vendorType,
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              vendorType == 'veg'
                                  ? '🥦 Veg'
                                  : vendorType == 'non_veg'
                                  ? '🍗 Non-Veg'
                                  : '🍽️ Both',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _vendorTypeColor(vendorType),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (shopImageUrl == null &&
                          (vendorBadge != null || rating != null))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              if (vendorBadge != null &&
                                  vendorBadge.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    vendorBadge,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (rating != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFD97706,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFD97706),
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$rating',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD97706),
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      if (isRestaurant && vendor['cuisine_type'] != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2563EB).withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            vendor['cuisine_type'],
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      if (categories.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: categories
                              .map(
                                (cat) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isActive,
                    onChanged: (_) =>
                        _toggleVendorStatus(vendor['id'], isActive),
                    activeThumbColor: AppColors.success,
                    inactiveThumbColor: AppColors.error,
                    activeTrackColor: AppColors.success.withOpacity(0.3),
                    inactiveTrackColor: AppColors.error.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vendor['area'] ?? '',
                        style: AppStyles.bodyText,
                      ),
                    ),
                  ],
                ),
                // ✅ UPDATED: "per person" label in admin vendor card
                if (isRestaurant &&
                    vendor['price_for_two'] != null &&
                    vendor['other_platform_avg'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Our platform: ₹${vendor['price_for_two']}/person',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'vs ₹${vendor['other_platform_avg']}/person elsewhere',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Shift badges
                Row(
                  children: [
                    if (vendor['morning_shift_active'] == true)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '🌅 $_morningShiftLabel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    if (vendor['evening_shift_active'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '🌆 $_eveningShiftLabel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    if (vendor['morning_shift_active'] != true &&
                        vendor['evening_shift_active'] != true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          '⚠️ No Shift Set',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
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
                          const SizedBox(width: 5),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _actionBtn(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      color: AppColors.primary,
                      onTap: () => _showVendorForm(vendor: vendor),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: () => _confirmDelete(vendor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    color: AppColors.background,
    child: const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted,
        size: 32,
      ),
    ),
  );

  void _confirmDelete(Map<String, dynamic> vendor) {
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
            const Text('Delete Vendor?', style: AppStyles.sectionHeader),
          ],
        ),
        content: Text(
          '"${vendor['name']}" will be permanently deleted.',
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
              _deleteVendor(vendor['id']);
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

  Widget _buildEmptyState() => Center(
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
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text('No Vendors Yet', style: AppStyles.sectionHeader),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add your first vendor',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  // ✅ UPDATED: helperText parameter added
  Widget _adminField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        helperText: helperText,
        helperStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
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
