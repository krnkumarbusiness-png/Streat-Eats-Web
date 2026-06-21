// lib/screens/admin/admin_menu_screen.dart
// v4.0 — New upsell system: direct item selection se popup configure hota hai
// ✅ Toggle ON → vendor categories dikhti hain
// ✅ Category tap → us category ke items checkbox list mein
// ✅ Items select karo → upsell_item_ids mein save
// ✅ Popup Title + Message custom fields preserved
// ✅ Half/Full ON hone pe vendor price field hide
// ✅ Realtime subscriptions preserved
// ✅ Sab kuch Hinglish mein

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/storage_service.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final _supabase = Supabase.instance.client;

  bool _statsExpanded = false;
  String _menuSearchQuery = ''; // add karo existing variables ke saath
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, dynamic>? _selectedVendor;
  bool _isLoadingVendors = true;
  bool _isLoadingMenu = false;
  Map<String, int> _vendorItemCounts = {};

  RealtimeChannel? _vendorChannel;
  RealtimeChannel? _menuChannel;

  final List<String> _fallbackCategories = [
    'Momos',
    'Burger',
    'Chowmein',
    'Pizza',
    'Chaat',
    'Maggi',
    'Sandwich',
    'Shake',
    'Soup',
    'Rolls',
    'Fries',
    'Noodles',
    'Other',
  ];

  static const List<Map<String, String>> _tagOptions = [
    {'label': 'None', 'value': ''},
    {'label': '🏆 Bestseller', 'value': 'Bestseller'},
    {'label': '✨ New', 'value': 'New'},
    {'label': '🌶️ Spicy', 'value': 'Spicy'},
    {'label': '❤️ Must Try', 'value': 'Must Try'},
    {'label': '🔥 Trending', 'value': 'Trending'},
    {'label': '💯 Chef Special', 'value': 'Chef Special'},
  ];

  String _categoryEmoji(String category) {
    final c = category.toLowerCase().trim();
    if (c.contains('momo')) return '🥟';
    if (c.contains('burger')) return '🍔';
    if (c.contains('chowmein') || c.contains('noodle')) return '🍜';
    if (c.contains('pizza')) return '🍕';
    if (c.contains('chaat')) return '🫙';
    if (c.contains('maggi')) return '🍝';
    if (c.contains('sandwich')) return '🥪';
    if (c.contains('shake') || c.contains('juice')) return '🥤';
    if (c.contains('soup')) return '🍲';
    if (c.contains('roll')) return '🌯';
    if (c.contains('fry') || c.contains('fries')) return '🍟';
    if (c.contains('samosa')) return '🔺';
    if (c.contains('tea') || c.contains('chai')) return '☕';
    return '🍽️';
  }

  String _primaryCategory(Map<String, dynamic> vendor) {
    final raw = vendor['category'] as String? ?? '';
    if (raw.trim().isEmpty) return 'Other';
    return raw.split(',').first.trim();
  }

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _subscribeVendorRealtime();
  }

  @override
  void dispose() {
    _vendorChannel?.unsubscribe();
    _menuChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeVendorRealtime() {
    _vendorChannel = _supabase
        .channel('admin_menu_vendors_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendors',
          callback: (payload) {
            if (mounted) _loadVendors(silent: true);
          },
        )
        .subscribe();
  }

  void _subscribeMenuRealtime(String vendorId) {
    _menuChannel?.unsubscribe();
    _menuChannel = _supabase
        .channel('admin_menu_items_realtime_$vendorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'vendor_id',
            value: vendorId,
          ),
          callback: (payload) {
            if (mounted && _selectedVendor?['id'] == vendorId) {
              _loadMenuItems(vendorId, silent: true);
            }
          },
        )
        .subscribe();
  }

  List<String> _getVendorCategories(Map<String, dynamic>? vendor) {
    if (vendor == null) return _fallbackCategories;
    final raw = vendor['category'] as String? ?? '';
    if (raw.trim().isEmpty) return _fallbackCategories;
    final cats = raw
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cats.isEmpty) return _fallbackCategories;
    if (!cats.contains('Other')) cats.add('Other');
    return cats;
  }

  Future<void> _loadVendors({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoadingVendors = true);
    try {
      final data = await _supabase
          .from('vendors')
          .select('id, name, area, category')
          .order('name');
      final countsRaw = await _supabase.from('menu_items').select('vendor_id');
      final Map<String, int> counts = {};
      for (final row in countsRaw as List<dynamic>) {
        final vid = row['vendor_id'] as String? ?? '';
        if (vid.isNotEmpty) counts[vid] = (counts[vid] ?? 0) + 1;
      }
      if (mounted) {
        setState(() {
          final newVendors = List<Map<String, dynamic>>.from(data);
          _vendorItemCounts = counts;
          _isLoadingVendors = false;
          if (_selectedVendor != null) {
            final stillExists = newVendors.any(
              (v) => v['id'] == _selectedVendor!['id'],
            );
            if (stillExists) {
              _selectedVendor = newVendors.firstWhere(
                (v) => v['id'] == _selectedVendor!['id'],
              );
            } else {
              _selectedVendor = newVendors.isNotEmpty ? newVendors.first : null;
              if (_selectedVendor != null) {
                _loadMenuItems(_selectedVendor!['id']);
              }
            }
          } else if (newVendors.isNotEmpty) {
            _selectedVendor = newVendors.first;
            _loadMenuItems(newVendors.first['id']);
          }
          _vendors = newVendors;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVendors = false);
      _snack('Vendors load nahi hue: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> get _filteredMenuItems {
    if (_menuSearchQuery.isEmpty) return _menuItems;
    return _menuItems.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final cat = (item['category'] as String? ?? '').toLowerCase();
      return name.contains(_menuSearchQuery) || cat.contains(_menuSearchQuery);
    }).toList();
  }

  void _applyMenuSearch() {
    setState(() {});
  }

  Future<void> _loadMenuItems(String vendorId, {bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingMenu = true;
        _menuSearchQuery = ''; // vendor switch pe search reset
      });
    }
    try {
      final data = await _supabase
          .from('menu_items')
          .select()
          .eq('vendor_id', vendorId)
          .order('category');
      if (mounted) {
        setState(() {
          _menuItems = List<Map<String, dynamic>>.from(data);
          _vendorItemCounts[vendorId] = _menuItems.length;
          _isLoadingMenu = false;
        });
      }
      _subscribeMenuRealtime(vendorId);
    } catch (e) {
      if (mounted) setState(() => _isLoadingMenu = false);
      _snack('Menu load nahi hua: $e', isError: true);
    }
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
      minWidth: 400,
      minHeight: 400,
      format: CompressFormat.jpeg,
    );
    return compressed != null ? File(compressed.path) : originalFile;
  }

  Future<String?> _uploadImage(File imageFile, String folder) async {
    final storageService = StorageService();
    final url = await storageService.uploadImage(imageFile, folder: folder);
    if (url == null) _snack('Image upload nahi hua', isError: true);
    return url;
  }

  Future<void> _toggleItemAvailability(String itemId, bool current) async {
    try {
      await _supabase
          .from('menu_items')
          .update({'is_available': !current})
          .eq('id', itemId);
      if (_selectedVendor != null) {
        await _loadMenuItems(_selectedVendor!['id'], silent: true);
      }
    } catch (e) {
      _snack('Update nahi hua: $e', isError: true);
    }
  }

  Future<void> _updateStockStatus(String itemId, String newStatus) async {
    try {
      await _supabase
          .from('menu_items')
          .update({
            'stock_status': newStatus,
            if (newStatus == 'sold_out') 'is_available': false,
            if (newStatus == 'available') 'is_available': true,
          })
          .eq('id', itemId);
      if (_selectedVendor != null) {
        await _loadMenuItems(_selectedVendor!['id'], silent: true);
      }
      final label = newStatus == 'available'
          ? 'Available ✅'
          : newStatus == 'low_stock'
          ? 'Low Stock ⚠️'
          : 'Sold Out ❌';
      _snack('$label set ho gaya');
    } catch (e) {
      _snack('Update nahi hua: $e', isError: true);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _supabase.from('menu_items').delete().eq('id', itemId);
      if (_selectedVendor != null) {
        await _loadMenuItems(_selectedVendor!['id'], silent: true);
      }
      _snack('Item delete ho gaya ✅');
    } catch (e) {
      _snack('Delete nahi hua: $e', isError: true);
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

  void _showStockStatusSheet(Map<String, dynamic> item) {
    final currentStatus = item['stock_status'] as String? ?? 'available';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            _stockOption(
              ctx: ctx,
              itemId: item['id'],
              status: 'available',
              currentStatus: currentStatus,
              label: 'Available',
              sublabel: 'Order ho sakta hai',
              emoji: '✅',
              color: AppColors.success,
            ),
            const SizedBox(height: 10),
            _stockOption(
              ctx: ctx,
              itemId: item['id'],
              status: 'low_stock',
              currentStatus: currentStatus,
              label: 'Low Stock',
              sublabel: 'Thoda bacha hai',
              emoji: '⚠️',
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            _stockOption(
              ctx: ctx,
              itemId: item['id'],
              status: 'sold_out',
              currentStatus: currentStatus,
              label: 'Sold Out',
              sublabel: 'Stock khatam',
              emoji: '❌',
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockOption({
    required BuildContext ctx,
    required String itemId,
    required String status,
    required String currentStatus,
    required String label,
    required String sublabel,
    required String emoji,
    required Color color,
  }) {
    final isSelected = currentStatus == status;
    return GestureDetector(
      onTap: () async {
        Navigator.pop(ctx);
        await _updateStockStatus(itemId, status);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ NEW: Upsell Item Picker Sheet
  // Category select → items checkbox list
  // ══════════════════════════════════════════════════════════════
  void _showUpsellItemPicker({
    required List<String> currentSelectedIds,
    required Function(List<String>) onSave,
  }) {
    if (_selectedVendor == null) return;
    final vendorCategories = _getVendorCategories(_selectedVendor);
    // Remove 'Other' from upsell categories
    final cats = vendorCategories.where((c) => c != 'Other').toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UpsellItemPickerSheet(
        supabase: _supabase,
        vendorId: null, // null = all vendors
        categories: const [], // ignored now
        currentSelectedIds: currentSelectedIds,
        onSave: onSave,
      ),
    );
  }

  void _showMenuItemForm({Map<String, dynamic>? item}) {
    if (_selectedVendor == null) {
      _snack('Pehle vendor select karo!', isError: true);
      return;
    }

    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final descCtrl = TextEditingController(text: item?['description'] ?? '');
    final longDescCtrl = TextEditingController(
      text: item?['long_description'] ?? '',
    );
    final vendorPriceCtrl = TextEditingController(
      text: item?['vendor_price']?.toString() ?? '',
    );
    final appPriceCtrl = TextEditingController(
      text: item?['app_price']?.toString() ?? '',
    );
    final originalPriceCtrl = TextEditingController(
      text: item?['original_price']?.toString() ?? '',
    );
    final halfPriceCtrl = TextEditingController(
      text: item?['half_price']?.toString() ?? '',
    );
    final fullPriceCtrl = TextEditingController(
      text: item?['full_price']?.toString() ?? '',
    );
    // ✅ NEW: Alag vendor cost fields for half/full
    final halfVendorPriceCtrl = TextEditingController(
      text: item?['half_vendor_price']?.toString() ?? '',
    );
    final fullVendorPriceCtrl = TextEditingController(
      text: item?['full_vendor_price']?.toString() ?? '',
    );
    final halfOriginalPriceCtrl = TextEditingController(
      text: item?['half_original_price']?.toString() ?? '',
    );
    final fullOriginalPriceCtrl = TextEditingController(
      text: item?['full_original_price']?.toString() ?? '',
    );
    final customCategoryCtrl = TextEditingController();

    // Upsell popup title/message
    final upsellTitleCtrl = TextEditingController(
      text: item?['upsell_popup_title'] as String? ?? '',
    );
    final upsellMessageCtrl = TextEditingController(
      text: item?['upsell_popup_message'] as String? ?? '',
    );

    // ✅ NEW: upsell_item_ids
    List<String> selectedUpsellIds = [];
    if (item != null) {
      final raw = item['upsell_item_ids'];
      if (raw is List) {
        selectedUpsellIds = raw.map((e) => e.toString()).toList();
      }
    }

    final vendorCategories = _getVendorCategories(_selectedVendor);
    final String existingCategory = item?['category'] ?? vendorCategories.first;
    String selectedCategory = vendorCategories.contains(existingCategory)
        ? existingCategory
        : 'Other';
    bool isCustomCategory =
        selectedCategory == 'Other' &&
        !vendorCategories.contains(existingCategory);
    if (isCustomCategory) customCategoryCtrl.text = existingCategory;

    bool isItemVeg = item?['is_veg'] ?? true;
    bool isDiscounted = item?['is_discounted'] as bool? ?? false;
    bool halfIsDiscounted = item?['half_is_discounted'] as bool? ?? false;
    bool fullIsDiscounted = item?['full_is_discounted'] as bool? ?? false;
    bool isRecommendedHome = item?['is_recommended_home'] as bool? ?? false;
    bool hasHalfFull = item?['has_half_full'] as bool? ?? false;
    String selectedTag = item?['tag'] as String? ?? '';

    // ✅ Show upsell toggle
    bool showUpsellPopup = selectedUpsellIds.isNotEmpty;

    File? selectedImageFile;
    String? existingImageUrl = item?['image_url'];
    bool isUploading = false;

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
                // ── Handle ──
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

                // ── Header ──
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
                        Icons.restaurant_menu_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item == null ? 'Item Add Karo' : 'Item Edit Karo',
                            style: AppStyles.sectionHeader,
                          ),
                          Text(
                            _selectedVendor!['name'],
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
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

                // ── Image Picker ──
                _buildLabel(
                  'Food Image',
                  'Customer ko menu mein yahi photo dikhegi',
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final file = await _pickAndCompressImage();
                    if (file != null) setModal(() => selectedImageFile = file);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 140,
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
                                  errorBuilder: (_, __, ___) => _imgPh(),
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
                                        '📷 Tap to change',
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
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary.withOpacity(0.5),
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Photo add karo',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const Text(
                                'Auto compress hogi',
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

                _adminField(
                  nameCtrl,
                  'Item ka naam (e.g. Chicken Momos)',
                  Icons.fastfood_outlined,
                ),
                const SizedBox(height: 12),
                _adminField(
                  descCtrl,
                  'Short description (menu card pe dikhega)',
                  Icons.notes_outlined,
                ),
                const SizedBox(height: 12),
                _buildLabel(
                  'Detail Description',
                  'Item detail screen mein dikhega',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: longDescCtrl,
                  maxLines: 4,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                  decoration: _inputDecoration(
                    'Aur kuch batao item ke baare mein...',
                    Icons.description_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tag ──
                _buildLabel('Item Tag', 'Menu card pe badge dikhega'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagOptions.map((tag) {
                    final isSelected = selectedTag == tag['value'];
                    return GestureDetector(
                      onTap: () => setModal(() => selectedTag = tag['value']!),
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
                          tag['label']!,
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

                // ── Category ──
                _buildLabel(
                  'Category',
                  '${_selectedVendor!['name']} ki categories',
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                      items: vendorCategories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    c == 'Other'
                                        ? Icons.edit_outlined
                                        : Icons.restaurant_outlined,
                                    color: c == 'Other'
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    c == 'Other' ? 'Other (Custom)' : c,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: c == 'Other'
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: c == 'Other'
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModal(() {
                        selectedCategory = val!;
                        isCustomCategory = val == 'Other';
                        if (!isCustomCategory) customCategoryCtrl.clear();
                      }),
                    ),
                  ),
                ),
                if (isCustomCategory) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCategoryCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                    decoration: _inputDecoration(
                      'Custom category likho (e.g. Rolls, Soup...)',
                      Icons.edit_outlined,
                      borderColor: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Pricing ──
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
                            Icons.currency_rupee_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'PRICING',
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
                      const SizedBox(height: 12),
                      if (!hasHalfFull)
                        Row(
                          children: [
                            Expanded(
                              child: _adminField(
                                vendorPriceCtrl,
                                'Vendor Price (₹)',
                                Icons.money_off_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _adminField(
                                appPriceCtrl,
                                'App Price (₹)',
                                Icons.sell_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        )
                      else
                        // Half/Full ON hai — 2 alag vendor price fields
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vendor Cost Prices (hidden from customer)',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _portionPriceField(
                                    halfVendorPriceCtrl,
                                    'Half vendor cost (₹)',
                                    AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _portionPriceField(
                                    fullVendorPriceCtrl,
                                    'Full vendor cost (₹)',
                                    AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.warning,
                            size: 13,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Vendor price customer ko nahi dikhta',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Half/Full ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hasHalfFull
                        ? const Color(0xFF7C3AED).withOpacity(0.04)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasHalfFull
                          ? const Color(0xFF7C3AED).withOpacity(0.3)
                          : AppColors.border,
                    ),
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
                              color: const Color(0xFF7C3AED).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Half / Full Portion',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  hasHalfFull
                                      ? 'Customer Half ya Full choose karega'
                                      : 'Single price',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasHalfFull
                                        ? const Color(0xFF7C3AED)
                                        : AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildToggle(
                            hasHalfFull,
                            const Color(0xFF7C3AED),
                            () => setModal(() => hasHalfFull = !hasHalfFull),
                          ),
                        ],
                      ),
                      if (hasHalfFull) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.15),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF7C3AED),
                                size: 13,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'App Price ignore hoga. Customer Half ya Full choose karega.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7C3AED),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _portionLabel(
                                    'Half',
                                    '🥘',
                                    const Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(height: 6),
                                  _portionPriceField(
                                    halfPriceCtrl,
                                    'Half price (₹)',
                                    const Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(height: 8),
                                  _discountToggleRow(
                                    'Half pe discount?',
                                    halfIsDiscounted,
                                    () => setModal(
                                      () =>
                                          halfIsDiscounted = !halfIsDiscounted,
                                    ),
                                  ),
                                  if (halfIsDiscounted) ...[
                                    const SizedBox(height: 8),
                                    _portionPriceField(
                                      halfOriginalPriceCtrl,
                                      'Half original price (₹)',
                                      AppColors.error,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _portionLabel(
                                    'Full',
                                    '🍲',
                                    AppColors.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  _portionPriceField(
                                    fullPriceCtrl,
                                    'Full price (₹)',
                                    AppColors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  _discountToggleRow(
                                    'Full pe discount?',
                                    fullIsDiscounted,
                                    () => setModal(
                                      () =>
                                          fullIsDiscounted = !fullIsDiscounted,
                                    ),
                                  ),
                                  if (fullIsDiscounted) ...[
                                    const SizedBox(height: 8),
                                    _portionPriceField(
                                      fullOriginalPriceCtrl,
                                      'Full original price (₹)',
                                      AppColors.error,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Discount ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDiscounted
                        ? AppColors.error.withOpacity(0.04)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDiscounted
                          ? AppColors.error.withOpacity(0.25)
                          : AppColors.border,
                    ),
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
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.local_offer_rounded,
                              color: AppColors.error.withOpacity(0.8),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Discount / Offer',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isDiscounted
                                      ? 'Strikethrough price dikhegi'
                                      : 'Discount OFF hai',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDiscounted
                                        ? AppColors.error
                                        : AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildToggle(
                            isDiscounted,
                            AppColors.error,
                            () => setModal(() => isDiscounted = !isDiscounted),
                          ),
                        ],
                      ),
                      if (isDiscounted) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.15),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.error,
                                size: 13,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Original Price = pehle wala (higher). App Price = actual pay karna hai.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.error,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _adminField(
                          originalPriceCtrl,
                          'Original Price (₹) — strikethrough',
                          Icons.money_off_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ════════════════════════════════════════════
                // ✅ NEW UPSELL SECTION — Simple aur clean
                // ════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: showUpsellPopup
                        ? const Color(0xFFFFD700).withOpacity(0.06)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: showUpsellPopup
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle row
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFD97706),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Upsell Popup Dikhao?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  showUpsellPopup
                                      ? selectedUpsellIds.isEmpty
                                            ? 'Koi item select nahi hua'
                                            : '${selectedUpsellIds.length} item${selectedUpsellIds.length > 1 ? 's' : ''} select hain'
                                      : 'Add to cart ke baad popup nahi aayega',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: showUpsellPopup
                                        ? const Color(0xFFD97706)
                                        : AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildToggle(
                            showUpsellPopup,
                            const Color(0xFFD97706),
                            () => setModal(() {
                              showUpsellPopup = !showUpsellPopup;
                              if (!showUpsellPopup) {
                                selectedUpsellIds = [];
                                upsellTitleCtrl.clear();
                                upsellMessageCtrl.clear();
                              }
                            }),
                          ),
                        ],
                      ),

                      if (showUpsellPopup) ...[
                        const SizedBox(height: 16),

                        // ── Popup Title ──
                        _buildLabel(
                          'Popup Title',
                          'Customer ko kya heading dikhegi',
                        ),
                        const SizedBox(height: 8),
                        _adminField(
                          upsellTitleCtrl,
                          'e.g. "Saath mein kuch aur? 🥤"',
                          Icons.title_rounded,
                        ),
                        const SizedBox(height: 12),

                        // ── Popup Message ──
                        _buildLabel(
                          'Popup Message',
                          'Heading ke neeche chhoti line',
                        ),
                        const SizedBox(height: 8),
                        _adminField(
                          upsellMessageCtrl,
                          'e.g. "Ek cold drink bhi le lo!"',
                          Icons.message_outlined,
                        ),
                        const SizedBox(height: 16),

                        // ── Item Selector ──
                        _buildLabel(
                          'Popup mein kaun si dishes dikhni chahiye?',
                          'Tap karo — categories aur items select karo',
                        ),
                        const SizedBox(height: 10),

                        // Selected items preview
                        if (selectedUpsellIds.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFD97706,
                                ).withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFD97706),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${selectedUpsellIds.length} item${selectedUpsellIds.length > 1 ? 's' : ''} select hain',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD97706),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setModal(() => selectedUpsellIds = []),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Open picker button
                        GestureDetector(
                          onTap: () => _showUpsellItemPicker(
                            currentSelectedIds: selectedUpsellIds,
                            onSave: (ids) =>
                                setModal(() => selectedUpsellIds = ids),
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD97706).withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedUpsellIds.isEmpty
                                      ? 'Items choose karo'
                                      : 'Items change karo',
                                  style: const TextStyle(
                                    color: Color(0xFFD97706),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (selectedUpsellIds.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '⚠️ Koi item select nahi hai — popup nahi aayega',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Veg Toggle ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isItemVeg
                        ? AppColors.success.withOpacity(0.04)
                        : AppColors.nonVegPrimary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isItemVeg
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.nonVegPrimary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isItemVeg
                                ? AppColors.success
                                : AppColors.nonVegPrimary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: isItemVeg
                                  ? AppColors.success
                                  : AppColors.nonVegPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isItemVeg ? 'Vegetarian' : 'Non-Vegetarian',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: isItemVeg
                                    ? AppColors.success
                                    : AppColors.nonVegPrimary,
                              ),
                            ),
                            Text(
                              isItemVeg
                                  ? 'Veg mode mein dikhega'
                                  : 'Non-veg mode mein dikhega',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setModal(() => isItemVeg = !isItemVeg),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 52,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isItemVeg
                                ? AppColors.success
                                : AppColors.nonVegPrimary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                left: isItemVeg ? 26 : 2,
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
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: isItemVeg ? 4 : 10,
                                  ),
                                  child: Text(
                                    isItemVeg ? 'V' : 'N',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
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
                const SizedBox(height: 12),

                // ── Show on Home ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRecommendedHome
                        ? AppColors.primary.withOpacity(0.04)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRecommendedHome
                          ? AppColors.primary.withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Home Screen pe Dikhao',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isRecommendedHome
                                  ? '"Recommended" section mein dikhega'
                                  : 'Home screen pe nahi dikhega',
                              style: TextStyle(
                                fontSize: 11,
                                color: isRecommendedHome
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildToggle(
                        isRecommendedHome,
                        AppColors.primary,
                        () => setModal(
                          () => isRecommendedHome = !isRecommendedHome,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Save Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              _snack('Item ka naam daalo!', isError: true);
                              return;
                            }
                            // ✅ SAHI — Half/Full ON hone pe vendor price skip karo
                            if (!hasHalfFull &&
                                vendorPriceCtrl.text.trim().isEmpty) {
                              _snack('Vendor price daalo!', isError: true);
                              return;
                            }
                            if (hasHalfFull) {
                              if (halfPriceCtrl.text.trim().isEmpty) {
                                _snack('Half price daalo!', isError: true);
                                return;
                              }
                              if (fullPriceCtrl.text.trim().isEmpty) {
                                _snack('Full price daalo!', isError: true);
                                return;
                              }
                            } else {
                              if (appPriceCtrl.text.trim().isEmpty) {
                                _snack('App price daalo!', isError: true);
                                return;
                              }
                            }
                            if (isCustomCategory &&
                                customCategoryCtrl.text.trim().isEmpty) {
                              _snack(
                                'Custom category naam daalo!',
                                isError: true,
                              );
                              return;
                            }
                            if (isDiscounted &&
                                originalPriceCtrl.text.trim().isEmpty) {
                              _snack('Original price daalo!', isError: true);
                              return;
                            }

                            final finalCategory = isCustomCategory
                                ? customCategoryCtrl.text.trim()
                                : selectedCategory;
                            setModal(() => isUploading = true);

                            String? imageUrl = existingImageUrl;
                            if (selectedImageFile != null) {
                              _snack('Image upload ho rahi hai...');
                              imageUrl = await _uploadImage(
                                selectedImageFile!,
                                'menu-items',
                              );
                              if (imageUrl == null) {
                                setModal(() => isUploading = false);
                                return;
                              }
                            }

                            final double finalAppPrice = hasHalfFull
                                ? (double.tryParse(halfPriceCtrl.text) ?? 0)
                                : (double.tryParse(appPriceCtrl.text) ?? 0);

                            final data = {
                              'vendor_id': _selectedVendor!['id'],
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'long_description':
                                  longDescCtrl.text.trim().isEmpty
                                  ? null
                                  : longDescCtrl.text.trim(),
                              'tag': selectedTag.isEmpty ? null : selectedTag,
                              'vendor_price':
                                  double.tryParse(vendorPriceCtrl.text) ?? 0,
                              'app_price': finalAppPrice,
                              'is_discounted': isDiscounted && !hasHalfFull,
                              'original_price': (isDiscounted && !hasHalfFull)
                                  ? double.tryParse(originalPriceCtrl.text)
                                  : null,
                              'category': finalCategory,
                              'is_available': true,
                              'is_veg': isItemVeg,
                              'stock_status': 'available',
                              'is_recommended_home': isRecommendedHome,
                              'has_half_full': hasHalfFull,
                              'half_price': hasHalfFull
                                  ? double.tryParse(halfPriceCtrl.text)
                                  : null,
                              'full_price': hasHalfFull
                                  ? double.tryParse(fullPriceCtrl.text)
                                  : null,
                              // ✅ NEW: Half/Full ke alag vendor costs
                              'half_vendor_price': hasHalfFull
                                  ? double.tryParse(halfVendorPriceCtrl.text)
                                  : null,
                              'full_vendor_price': hasHalfFull
                                  ? double.tryParse(fullVendorPriceCtrl.text)
                                  : null,
                              'half_is_discounted': hasHalfFull
                                  ? halfIsDiscounted
                                  : false,
                              'half_original_price':
                                  (hasHalfFull && halfIsDiscounted)
                                  ? double.tryParse(halfOriginalPriceCtrl.text)
                                  : null,
                              'full_is_discounted': hasHalfFull
                                  ? fullIsDiscounted
                                  : false,
                              'full_original_price':
                                  (hasHalfFull && fullIsDiscounted)
                                  ? double.tryParse(fullOriginalPriceCtrl.text)
                                  : null,
                              // ✅ Upsell fields
                              'upsell_popup_title':
                                  showUpsellPopup &&
                                      upsellTitleCtrl.text.trim().isNotEmpty
                                  ? upsellTitleCtrl.text.trim()
                                  : null,
                              'upsell_popup_message':
                                  showUpsellPopup &&
                                      upsellMessageCtrl.text.trim().isNotEmpty
                                  ? upsellMessageCtrl.text.trim()
                                  : null,
                              'upsell_item_ids': showUpsellPopup
                                  ? List<String>.from(selectedUpsellIds)
                                  : <String>[],
                              if (imageUrl != null) 'image_url': imageUrl,
                            };

                            try {
                              if (item == null) {
                                await _supabase.from('menu_items').insert(data);
                              } else {
                                await _supabase
                                    .from('menu_items')
                                    .update(data)
                                    .eq('id', item['id']);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadMenuItems(
                                _selectedVendor!['id'],
                                silent: true,
                              );
                              _snack(
                                item == null
                                    ? 'Item add ho gaya! ✅'
                                    : 'Item update ho gaya! ✅',
                              );
                            } catch (e) {
                              setModal(() => isUploading = false);
                              _snack('Save nahi hua: $e', isError: true);
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
                            item == null ? 'Item Add Karo' : 'Update Karo',
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

  // ── Helper Widgets ──────────────────────────────────────
  Widget _buildLabel(String title, String subtitle) {
    return Column(
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
    );
  }

  Widget _buildToggle(bool value, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? activeColor : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: value ? 26 : 2,
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
    );
  }

  Widget _portionLabel(String label, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _portionPriceField(
    TextEditingController ctrl,
    String hint,
    Color color,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
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
        prefixText: '₹ ',
        prefixStyle: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
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
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _discountToggleRow(String label, bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? AppColors.error.withOpacity(0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppColors.error.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_rounded,
              color: value ? AppColors.error : AppColors.textMuted,
              size: 13,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: value ? AppColors.error : AppColors.textMuted,
                ),
              ),
            ),
            _buildToggle(value, AppColors.error, onTap),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Color? borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontFamily: 'Poppins',
      ),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor ?? AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: borderColor?.withOpacity(0.4) ?? AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _adminField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
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
      decoration: _inputDecoration(hint, icon),
    );
  }

  Widget _imgPh() => Container(
    color: AppColors.background,
    child: const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted,
        size: 32,
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // BUILD — Main scaffold
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final availableCount = _menuItems
        .where((i) => i['is_available'] == true)
        .length;
    final soldOutCount = _menuItems
        .where((i) => i['stock_status'] == 'sold_out')
        .length;
    final lowStockCount = _menuItems
        .where((i) => i['stock_status'] == 'low_stock')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Menu Items', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await _loadVendors();
              if (_selectedVendor != null) {
                await _loadMenuItems(_selectedVendor!['id']);
              }
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      floatingActionButton: _selectedVendor != null
          ? FloatingActionButton.extended(
              onPressed: () => _showMenuItemForm(),
              backgroundColor: AppColors.primary,
              elevation: 2,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Item',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                ),
              ),
            )
          : null,
      body: _isLoadingVendors
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : _vendors.isEmpty
          ? _buildNoVendorsState()
          : Column(
              children: [
                _buildVendorSelector(),
                if (_menuItems.isNotEmpty)
                  _buildStatsBar(availableCount, soldOutCount, lowStockCount),
                Expanded(
                  child: _isLoadingMenu
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _menuItems.isEmpty
                      ? _buildEmptyMenuState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () =>
                              _loadMenuItems(_selectedVendor!['id']),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _filteredMenuItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildMenuItemCard(_filteredMenuItems[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildVendorSelector() {
    if (_selectedVendor == null) return const SizedBox.shrink();
    final primaryCat = _primaryCategory(_selectedVendor!);
    final emoji = _categoryEmoji(primaryCat);
    final itemCount = _vendorItemCounts[_selectedVendor!['id']] ?? 0;
    final area = _selectedVendor!['area'] as String? ?? '';

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVendor!['name'],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textMuted,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              area,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              primaryCat,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$itemCount',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'items',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: _showVendorPickerSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Vendor Switch Karo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_vendors.length} vendors',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (val) {
                setState(() => _menuSearchQuery = val.trim().toLowerCase());
                _applyMenuSearch();
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: 'Menu item search karo...',
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
                fillColor: AppColors.background,
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
          Container(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  void _showVendorPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vendor Select Karo',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${_vendors.length} vendors registered',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.border),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _vendors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final v = _vendors[i];
                  final isSelected = _selectedVendor?['id'] == v['id'];
                  final cat = _primaryCategory(v);
                  final emo = _categoryEmoji(cat);
                  final count = _vendorItemCounts[v['id']] ?? 0;
                  final vArea = v['area'] as String? ?? '';
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedVendor = v);
                      _loadMenuItems(v['id']);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.4)
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.14)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emo,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v['name'],
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.textMuted,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      vArea,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '· $cat',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  '$count items',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(
    int availableCount,
    int soldOutCount,
    int lowStockCount,
  ) {
    final totalItems = _menuItems.length;
    final vegCount = _menuItems.where((i) => i['is_veg'] == true).length;
    final halfFullCount = _menuItems
        .where((i) => i['has_half_full'] == true)
        .length;
    final upsellCount = _menuItems.where((i) {
      final ids = i['upsell_item_ids'];
      return ids is List && ids.isNotEmpty;
    }).length;

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Toggle header
          GestureDetector(
            onTap: () => setState(() => _statsExpanded = !_statsExpanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Stats — $totalItems items, $availableCount available',
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
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard(
                        'Total',
                        '$totalItems',
                        Icons.restaurant_menu_outlined,
                        AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Available',
                        '$availableCount',
                        Icons.check_circle_outline_rounded,
                        AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Low Stock',
                        '$lowStockCount',
                        Icons.warning_amber_rounded,
                        AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Sold Out',
                        '$soldOutCount',
                        Icons.remove_shopping_cart_outlined,
                        AppColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatCard(
                        'Veg',
                        '$vegCount',
                        Icons.eco_outlined,
                        AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Non-Veg',
                        '${totalItems - vegCount}',
                        Icons.set_meal_outlined,
                        AppColors.nonVegPrimary,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Half/Full',
                        '$halfFullCount',
                        Icons.restaurant_rounded,
                        const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Upsell',
                        '$upsellCount',
                        Icons.star_rounded,
                        const Color(0xFFD97706),
                      ),
                    ],
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
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

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final isAvailable = item['is_available'] as bool? ?? false;
    final isVeg = item['is_veg'] as bool? ?? true;
    final stockStatus = item['stock_status'] as String? ?? 'available';
    final vendorPrice = item['vendor_price'] as num? ?? 0;
    final appPrice = item['app_price'] as num? ?? 0;
    final isDiscounted = item['is_discounted'] as bool? ?? false;
    final margin = appPrice - vendorPrice;
    final imageUrl = item['image_url'] as String?;
    final tag = item['tag'] as String?;
    final isRecommendedHome = item['is_recommended_home'] as bool? ?? false;
    final hasHalfFull = item['has_half_full'] as bool? ?? false;
    final halfPrice = item['half_price'] as num?;
    final fullPrice = item['full_price'] as num?;
    final upsellIds = item['upsell_item_ids'];
    final hasUpsell = upsellIds is List && upsellIds.isNotEmpty;

    Color stockColor;
    String stockLabel;
    IconData stockIcon;
    switch (stockStatus) {
      case 'low_stock':
        stockColor = AppColors.warning;
        stockLabel = 'Low Stock';
        stockIcon = Icons.warning_amber_rounded;
        break;
      case 'sold_out':
        stockColor = AppColors.error;
        stockLabel = 'Sold Out';
        stockIcon = Icons.remove_shopping_cart_outlined;
        break;
      default:
        stockColor = AppColors.success;
        stockLabel = 'Available';
        stockIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stockStatus == 'sold_out'
              ? AppColors.error.withOpacity(0.3)
              : AppColors.border,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: stockStatus == 'sold_out'
                  ? AppColors.error.withOpacity(0.04)
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(color: stockColor.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _smallIconBox(),
                        )
                      : _smallIconBox(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isVeg
                                    ? AppColors.success
                                    : AppColors.nonVegPrimary,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isVeg
                                      ? AppColors.success
                                      : AppColors.nonVegPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: AppStyles.cardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasHalfFull) ...[
                            const SizedBox(width: 4),
                            _badge('H/F', const Color(0xFF7C3AED)),
                          ],
                          if (tag != null && tag.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            _badge(tag, AppColors.primary),
                          ],
                          if (isRecommendedHome) ...[
                            const SizedBox(width: 4),
                            _badge('🏠', const Color(0xFF2563EB)),
                          ],
                          if (isDiscounted) ...[
                            const SizedBox(width: 4),
                            _badge('SALE', AppColors.error),
                          ],
                          if (hasUpsell) ...[
                            const SizedBox(width: 4),
                            _badge('⭐', const Color(0xFFD97706)),
                          ],
                        ],
                      ),
                      if (item['description'] != null &&
                          item['description'].toString().isNotEmpty)
                        Text(
                          item['description'],
                          style: AppStyles.bodyText.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isAvailable,
                    onChanged: (_) =>
                        _toggleItemAvailability(item['id'], isAvailable),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _pricePill('Cost', '₹$vendorPrice', AppColors.error),
                    const SizedBox(width: 6),
                    if (hasHalfFull &&
                        halfPrice != null &&
                        fullPrice != null) ...[
                      _pricePill(
                        'Half',
                        '₹$halfPrice',
                        const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 6),
                      _pricePill('Full', '₹$fullPrice', AppColors.primary),
                    ] else
                      _pricePill('App', '₹$appPrice', AppColors.acceptedBlue),
                    const SizedBox(width: 6),
                    _pricePill(
                      'Margin',
                      '₹$margin',
                      margin > 0 ? AppColors.success : AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showStockStatusSheet(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stockColor.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(stockIcon, color: stockColor, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              stockLabel,
                              style: TextStyle(
                                color: stockColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: stockColor,
                              size: 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    _iconAction(
                      Icons.edit_outlined,
                      AppColors.primary,
                      () => _showMenuItemForm(item: item),
                    ),
                    const SizedBox(width: 8),
                    _iconAction(
                      Icons.delete_outline_rounded,
                      AppColors.error,
                      () => _confirmDelete(item),
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

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        fontFamily: 'Poppins',
      ),
    ),
  );
  Widget _smallIconBox() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.fastfood_rounded,
      color: AppColors.primary,
      size: 20,
    ),
  );
  Widget _pricePill(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    ),
  );
  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
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

  void _confirmDelete(Map<String, dynamic> item) {
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
            const Text('Delete?', style: AppStyles.sectionHeader),
          ],
        ),
        content: Text(
          '"${item['name']}" ko delete karna chahte ho?',
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
              _deleteItem(item['id']);
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

  Widget _buildNoVendorsState() => Center(
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
          const Text('Pehle Vendor Add Karo', style: AppStyles.sectionHeader),
          const SizedBox(height: 8),
          const Text(
            'Vendors tab mein jaao aur vendor add karo',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  Widget _buildEmptyMenuState() => Center(
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
              Icons.restaurant_menu_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Koi Item Nahi', style: AppStyles.sectionHeader),
          const SizedBox(height: 8),
          const Text(
            'Add Item button se pehla menu item add karo',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// ✅ NEW: Upsell Item Picker Sheet
// Category chips → item checkboxes
// ══════════════════════════════════════════════════════════════════
class _UpsellItemPickerSheet extends StatefulWidget {
  final SupabaseClient supabase;
  final String? vendorId; // null = all vendors
  final List<String> categories; // ignored
  final List<String> currentSelectedIds;
  final Function(List<String>) onSave;

  const _UpsellItemPickerSheet({
    required this.supabase,
    this.vendorId,
    required this.categories,
    required this.currentSelectedIds,
    required this.onSave,
  });

  @override
  State<_UpsellItemPickerSheet> createState() => _UpsellItemPickerSheetState();
}

class _UpsellItemPickerSheetState extends State<_UpsellItemPickerSheet> {
  // Vendor list
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedVendor;

  // Items of selected vendor
  List<Map<String, dynamic>> _allVendorItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String? _selectedCategory;
  List<String> _vendorCategories = [];

  bool _isLoadingVendors = true;
  bool _isLoadingItems = false;
  late List<String> _selectedIds;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentSelectedIds);
    _loadAllVendors();
    _searchCtrl.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allVendorItems.where((item) {
        final nameMatch = (item['name'] as String? ?? '')
            .toLowerCase()
            .contains(query);
        final catMatch =
            _selectedCategory == null ||
            _selectedCategory == 'All' ||
            item['category'] == _selectedCategory;
        return nameMatch && catMatch;
      }).toList();
    });
  }

  Future<void> _loadAllVendors() async {
    setState(() => _isLoadingVendors = true);
    try {
      final data = await widget.supabase
          .from('vendors')
          .select('id, name, area, category')
          .order('name');
      final vendors = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _vendors = vendors;
          _isLoadingVendors = false;
          if (vendors.isNotEmpty) {
            _selectedVendor = vendors.first;
            _loadVendorItems(vendors.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> _loadVendorItems(Map<String, dynamic> vendor) async {
    setState(() {
      _isLoadingItems = true;
      _selectedVendor = vendor;
      _selectedCategory = 'All';
      _searchCtrl.clear();
    });
    try {
      final data = await widget.supabase
          .from('menu_items')
          .select(
            'id, name, image_url, app_price, half_price, has_half_full, '
            'is_available, stock_status, category',
          )
          .eq('vendor_id', vendor['id'])
          .order('name');
      final items = List<Map<String, dynamic>>.from(data);

      // Build category list
      final catSet = <String>{'All'};
      for (final item in items) {
        final c = item['category'] as String?;
        if (c != null && c.isNotEmpty) catSet.add(c);
      }

      if (mounted) {
        setState(() {
          _allVendorItems = items;
          _filteredItems = items;
          _vendorCategories = catSet.toList();
          _isLoadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allVendorItems.where((item) {
        final nameMatch = (item['name'] as String? ?? '')
            .toLowerCase()
            .contains(query);
        final catMatch =
            _selectedCategory == null ||
            _selectedCategory == 'All' ||
            item['category'] == _selectedCategory;
        return nameMatch && catMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upsell Items Choose Karo',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _selectedIds.isEmpty
                                ? 'Koi item select nahi'
                                : '${_selectedIds.length} select hain',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _selectedIds.isEmpty
                                  ? AppColors.textMuted
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                const SizedBox(height: 14),

                // ── Vendor Horizontal Scroll ──
                _isLoadingVendors
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _vendors.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final v = _vendors[i];
                            final isActive = _selectedVendor?['id'] == v['id'];
                            return GestureDetector(
                              onTap: () => _loadVendorItems(v),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  v['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 10),

                // ── Search ──
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilters(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Item search karo...',
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
                    fillColor: AppColors.background,
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
                const SizedBox(height: 10),

                // ── Category Chips ──
                if (_vendorCategories.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _vendorCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _vendorCategories[i];
                        final isActive = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            _applyFilters();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFD97706)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFD97706)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.border),
              ],
            ),
          ),

          // ── Items List ──
          Expanded(
            child: _isLoadingItems
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          color: AppColors.textMuted,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _allVendorItems.isEmpty
                              ? 'Is vendor ka koi item nahi'
                              : 'Koi result nahi mila',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = _filteredItems[i];
                      final id = it['id'].toString();
                      final isSelected = _selectedIds.contains(id);
                      final price = it['has_half_full'] == true
                          ? it['half_price']
                          : it['app_price'];
                      final isSoldOut = it['stock_status'] == 'sold_out';

                      return GestureDetector(
                        onTap: isSoldOut
                            ? null
                            : () => setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.06)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.4)
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: it['image_url'] != null
                                    ? Image.network(
                                        it['image_url'],
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _itemPh(),
                                      )
                                    : _itemPh(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it['name'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${price?.toString() ?? '0'}${it['has_half_full'] == true ? '+' : ''}',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Vendor name chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _selectedVendor?['name'] ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        if (isSoldOut) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Sold Out',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Save Button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_selectedIds);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Koi item select nahi — phir bhi save karo'
                        : '${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''} save karo ✅',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemPh() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Center(
      child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 24),
    ),
  );
}
