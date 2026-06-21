// lib/screens/admin/admin_categories_screen.dart
// v3.0 — ENHANCED: 4 tabs — All, Street Food, Restaurant, Sweets
// ✅ Tab-wise categories: vendors ki category field se (street/restaurant)
//    + specialty_category field se (sweets)
// ✅ Photo upload per category
// ✅ is_show_on_home toggle
// ✅ food_categories table mein save hota hai

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/storage_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Tab index: 0=All, 1=Street Food, 2=Restaurant, 3=Sweets
  int _activeTab = 0;

  // All unique categories grouped by type
  List<String> _allCategories = [];
  List<String> _streetFoodCategories = [];
  List<String> _restaurantCategories = [];
  List<String> _sweetsCategories = [];

  // food_categories table data — name → row
  Map<String, Map<String, dynamic>> _savedCategories = {};

  bool _isLoading = true;
  bool _showOnlyHidden = false;

  // ── Emoji map ──────────────────────────────────────────────
  String _emoji(String cat) {
    final c = cat.toLowerCase().trim();
    if (c == 'all') return '✦';
    if (c.contains('burger')) return '🍔';
    if (c.contains('chowmein') || c.contains('noodle')) return '🍜';
    if (c.contains('pizza')) return '🍕';
    if (c.contains('chaat')) return '🍛';
    if (c.contains('maggi')) return '🍝';
    if (c.contains('sandwich')) return '🥪';
    if (c.contains('shake') || c.contains('juice')) return '🥤';
    if (c.contains('soup')) return '🍲';
    if (c.contains('roll')) return '🌯';
    if (c.contains('fry') || c.contains('fries')) return '🍟';
    if (c.contains('samosa')) return '🔺';
    if (c.contains('tea') || c.contains('chai')) return '☕';
    if (c.contains('rice') || c.contains('biryani')) return '🍚';
    if (c.contains('chicken')) return '🍗';
    if (c.contains('paneer')) return '🧀';
    // Sweets emojis
    if (c.contains('mithai') || c.contains('sweet')) return '🍮';
    if (c.contains('barfi') || c.contains('burfi')) return '🍬';
    if (c.contains('halwa')) return '🍯';
    if (c.contains('ice') || c.contains('cream')) return '🍦';
    if (c.contains('cake')) return '🎂';
    if (c.contains('gulab') || c.contains('jamun')) return '🔴';
    if (c.contains('ladoo') || c.contains('laddoo')) return '🟡';
    if (c.contains('chocolate')) return '🍫';
    if (c.contains('jalebi')) return '🟠';
    if (c.contains('kheer')) return '🥛';
    if (c.contains('peda')) return '🟤';
    // Restaurant cuisine
    if (c.contains('north indian')) return '🍛';
    if (c.contains('south indian')) return '🥘';
    if (c.contains('chinese')) return '🥡';
    if (c.contains('italian')) return '🍝';
    if (c.contains('continental')) return '🥩';
    if (c.contains('fast food')) return '🍟';
    return '🍽️';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Current tab categories ────────────────────────────────
  List<String> get _currentCategories {
    switch (_activeTab) {
      case 1:
        return _streetFoodCategories;
      case 2:
        return _restaurantCategories;
      case 3:
        return _sweetsCategories;
      default:
        return _allCategories;
    }
  }

  // ── Data Loading ──────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadVendorCategories(), _loadSavedCategories()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadVendorCategories() async {
    try {
      final rows = await _supabase
          .from('vendors')
          .select('category, business_type, specialty_category');

      final Set<String> allSet = {};
      final Set<String> streetSet = {};
      final Set<String> restSet = {};
      final Set<String> sweetsSet = {};

      for (final row in (rows as List)) {
        final businessType = row['business_type'] as String? ?? 'street_food';
        final rawCat = row['category'] as String? ?? '';
        final specialty = row['specialty_category'] as String? ?? '';

        final cats = rawCat
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();

        for (final cat in cats) {
          if (businessType == 'street_food') {
            streetSet.add(cat);
            allSet.add(cat);
          }
          if (businessType == 'restaurant') {
            restSet.add(cat);
            allSet.add(cat);
          }
          if (businessType == 'sweets') {
            sweetsSet.add(cat); // ✅ sirf sweetsSet
          }
        }

        if (businessType == 'sweets' && specialty.isNotEmpty) {
          specialty
              .split(',')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .forEach((c) {
                sweetsSet.add(c); // ✅ sirf sweetsSet
              });
        }
      }

      // ✅ food_categories table se manually saved sweets categories
      try {
        final savedRows = await _supabase
            .from('food_categories')
            .select('name, category_type')
            .eq('category_type', 'sweets');
        for (final r in (savedRows as List)) {
          final name = r['name'] as String? ?? '';
          if (name.isNotEmpty) {
            sweetsSet.add(name); // ✅ sirf sweetsSet
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allCategories = ['All', ...allSet.toList()..sort()];
          _streetFoodCategories = ['All', ...streetSet.toList()..sort()];
          _restaurantCategories = ['All', ...restSet.toList()..sort()];
          _sweetsCategories = ['All', ...sweetsSet.toList()..sort()];
        });
      }
    } catch (e) {
      _snack('Categories load failed: $e', isError: true);
    }
  }

  Future<void> _loadSavedCategories() async {
    try {
      final rows = await _supabase.from('food_categories').select();
      final map = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final name = row['name'] as String? ?? '';
        if (name.isNotEmpty) map[name] = Map<String, dynamic>.from(row);
      }
      if (mounted) setState(() => _savedCategories = map);
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────
  bool _hasPhoto(String catName) {
    final url = _savedCategories[catName]?['image_url'] as String?;
    return url != null && url.isNotEmpty;
  }

  bool _isShowOnHome(String catName) {
    final row = _savedCategories[catName];
    if (row == null) return true;
    return row['is_show_on_home'] as bool? ?? true;
  }

  // ── Image Pick & Compress ─────────────────────────────────
  Future<File?> _pickAndCompressImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final orig = File(picked.path);
    final compressed = await FlutterImageCompress.compressAndGetFile(
      orig.path,
      '${orig.parent.path}/cat_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 75,
      minWidth: 300,
      minHeight: 300,
      format: CompressFormat.jpeg,
    );
    return compressed != null ? File(compressed.path) : orig;
  }

  Future<String?> _uploadImage(File imageFile) async {
    final url = await StorageService().uploadImage(
      imageFile,
      folder: 'categories',
    );
    if (url == null) _snack('Image upload failed', isError: true);
    return url;
  }

  // ── Save / Update ─────────────────────────────────────────
  Future<void> _saveCategoryImage(String categoryName, String imageUrl) async {
    try {
      final existing = _savedCategories[categoryName];
      if (existing != null) {
        await _supabase
            .from('food_categories')
            .update({
              'image_url': imageUrl,
              'category_type': _activeTab == 3
                  ? 'sweets'
                  : _activeTab == 2
                  ? 'restaurant'
                  : _activeTab == 1
                  ? 'street_food'
                  : 'general',
            })
            .eq('id', existing['id']);
      } else {
        await _supabase.from('food_categories').insert({
          'name': categoryName,
          'image_url': imageUrl,
          'sort_order': _allCategories.indexOf(categoryName),
          'is_active': true,
          'is_show_on_home': true,
          // ✅ Active tab ka type save karo
          'category_type': _activeTab == 3
              ? 'sweets'
              : _activeTab == 2
              ? 'restaurant'
              : _activeTab == 1
              ? 'street_food'
              : 'general',
        });
      }
      await _loadSavedCategories();
      _snack('$categoryName ka photo save ho gaya ✅');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    }
  }

  Future<void> _removeImage(String categoryName) async {
    try {
      final existing = _savedCategories[categoryName];
      if (existing == null) return;
      await _supabase
          .from('food_categories')
          .update({'image_url': null})
          .eq('id', existing['id']);
      await _loadSavedCategories();
      _snack('$categoryName ki photo remove ho gayi');
    } catch (e) {
      _snack('Remove failed: $e', isError: true);
    }
  }

  Future<void> _toggleShowOnHome(String categoryName) async {
    final newVal = !_isShowOnHome(categoryName);
    try {
      final existing = _savedCategories[categoryName];
      if (existing != null) {
        await _supabase
            .from('food_categories')
            .update({'is_show_on_home': newVal})
            .eq('id', existing['id']);
      } else {
        await _supabase.from('food_categories').insert({
          'name': categoryName,
          'image_url': null,
          'sort_order': _allCategories.indexOf(categoryName),
          'is_active': true,
          'is_show_on_home': newVal,
          // ✅ Active tab ka type save karo
          'category_type': _activeTab == 3
              ? 'sweets'
              : _activeTab == 2
              ? 'restaurant'
              : _activeTab == 1
              ? 'street_food'
              : 'general',
        });
      }
      await _loadSavedCategories();
      _snack(
        newVal
            ? '$categoryName home pe dikhega ✅'
            : '$categoryName home se hide ho gaya 🙈',
      );
    } catch (e) {
      _snack('Update failed: $e', isError: true);
    }
  }

  // ── Snackbar ──────────────────────────────────────────────
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

  // ── Image Editor Bottom Sheet ─────────────────────────────
  void _showImageEditor(String categoryName) {
    final existing = _savedCategories[categoryName];
    final currentImageUrl = existing?['image_url'] as String?;
    File? selectedFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _emoji(categoryName),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categoryName, style: AppStyles.sectionHeader),
                        const Text(
                          'Category ka photo set karo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
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

              // Image picker area
              GestureDetector(
                onTap: isUploading
                    ? null
                    : () async {
                        final file = await _pickAndCompressImage();
                        if (file != null) setModal(() => selectedFile = file);
                      },
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedFile != null
                          ? AppColors.primary
                          : AppColors.border,
                      width: selectedFile != null ? 2 : 1,
                    ),
                  ),
                  child: selectedFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(selectedFile!, fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setModal(() => selectedFile = null),
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
                                      horizontal: 12,
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
                      : currentImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                currentImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _emojiBox(categoryName),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
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
                            Text(
                              _emoji(categoryName),
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Category ki photo add karo',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Home screen pe circle mein dikhegi',
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
              const SizedBox(height: 14),

              // Info banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedFile != null
                            ? 'Naya photo select hua — ab Save karo!'
                            : currentImageUrl != null
                            ? 'Photo set hai — change ya remove kar sakte ho'
                            : 'Abhi sirf emoji dikh raha hai — photo add karo',
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
              const SizedBox(height: 16),

              // Action buttons
              if (selectedFile != null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            setModal(() => isUploading = true);
                            final url = await _uploadImage(selectedFile!);
                            if (url == null) {
                              setModal(() => isUploading = false);
                              return;
                            }
                            await _saveCategoryImage(categoryName, url);
                            if (ctx.mounted) Navigator.pop(ctx);
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
                                'Upload ho rahi hai...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Save Karo ✅',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),

              if (selectedFile == null && currentImageUrl != null)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _removeImage(categoryName);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            final file = await _pickAndCompressImage();
                            if (file != null) {
                              setModal(() => selectedFile = file);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Change Photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              if (selectedFile == null && currentImageUrl == null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final file = await _pickAndCompressImage();
                      if (file != null) setModal(() => selectedFile = file);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Photo Select Karo',
                      style: TextStyle(
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
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cats = _currentCategories;
    final withPhoto = cats.where((c) => _hasPhoto(c)).length;
    final homeOnCount = cats.where((c) => _isShowOnHome(c)).length;
    final homeOffCount = cats.length - homeOnCount;

    final displayCategories = _showOnlyHidden
        ? cats.where((c) => !_isShowOnHome(c)).toList()
        : cats;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _activeTab == 3
          ? FloatingActionButton.extended(
              onPressed: _showAddSweetsCategoryDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Sweet Category',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Food Categories', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.border),
              _buildTabBar(),
            ],
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
          : cats.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildStatsBar(
                    withPhoto,
                    cats.length - withPhoto,
                    homeOnCount,
                    homeOffCount,
                  ),
                  _buildFilterToggle(homeOffCount),
                  Expanded(
                    child: displayCategories.isEmpty
                        ? _buildAllVisibleState()
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                            itemCount: displayCategories.length,
                            itemBuilder: (_, i) =>
                                _buildCategoryCard(displayCategories[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      ('All', Icons.apps_rounded, _allCategories.length - 1),
      (
        'Street Food',
        Icons.storefront_rounded,
        _streetFoodCategories.length - 1,
      ),
      (
        'Restaurant',
        Icons.restaurant_rounded,
        _restaurantCategories.length - 1,
      ),
      ('Sweets', Icons.cake_rounded, _sweetsCategories.length - 1),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _activeTab == i;
          final count = tabs[i].$3;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                setState(() => _activeTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i].$2,
                      size: 14,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].$1,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white.withOpacity(0.8)
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────
  Widget _buildStatsBar(
    int withPhoto,
    int withoutPhoto,
    int homeOn,
    int homeOff,
  ) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _statChip(
            'Total',
            '${_currentCategories.length}',
            Icons.category_outlined,
            AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          _statChip(
            'Photo',
            '$withPhoto',
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          const SizedBox(width: 6),
          _statChip(
            'No Photo',
            '$withoutPhoto',
            Icons.image_not_supported_outlined,
            AppColors.warning,
          ),
          const SizedBox(width: 6),
          _statChip(
            'Hidden',
            '$homeOff',
            Icons.visibility_off_outlined,
            AppColors.error,
          ),
        ],
      ),
    );
  }

  // ── Filter Toggle ─────────────────────────────────────────
  Widget _buildFilterToggle(int homeOff) {
    return GestureDetector(
      onTap: () => setState(() => _showOnlyHidden = !_showOnlyHidden),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _showOnlyHidden
              ? AppColors.error.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showOnlyHidden
                ? AppColors.error.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _showOnlyHidden
                  ? Icons.visibility_off_rounded
                  : Icons.filter_list_rounded,
              color: _showOnlyHidden ? AppColors.error : AppColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _showOnlyHidden
                    ? 'Sirf hidden categories ($homeOff) — tap to show all'
                    : 'Saari categories dikh rahi hain — tap to filter hidden',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: _showOnlyHidden
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: _showOnlyHidden ? AppColors.error : AppColors.border,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: _showOnlyHidden ? 19 : 1,
                    top: 1,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Card ─────────────────────────────────────────
  Widget _buildCategoryCard(String catName) {
    final hasPhoto = _hasPhoto(catName);
    final imageUrl = _savedCategories[catName]?['image_url'] as String?;
    final showOnHome = _isShowOnHome(catName);

    return GestureDetector(
      onTap: () => _showImageEditor(catName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !showOnHome
                ? AppColors.error.withOpacity(0.4)
                : hasPhoto
                ? AppColors.success.withOpacity(0.4)
                : AppColors.border,
            width: !showOnHome || hasPhoto ? 1.5 : 1,
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
            // Image / Emoji area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasPhoto && imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _emojiBox(catName),
                          )
                        : _emojiBox(catName),

                    if (!showOnHome)
                      Container(color: Colors.black.withOpacity(0.45)),

                    if (!showOnHome)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: AppColors.error.withOpacity(0.85),
                          child: const Center(
                            child: Text(
                              'Hidden 🙈',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Edit icon
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),

                    // Green tick
                    if (hasPhoto && showOnHome)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Name + toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Column(
                children: [
                  Text(
                    catName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: showOnHome
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => _toggleShowOnHome(catName),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: showOnHome
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: showOnHome
                              ? AppColors.primary.withOpacity(0.3)
                              : AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            showOnHome
                                ? Icons.home_rounded
                                : Icons.visibility_off_rounded,
                            color: showOnHome
                                ? AppColors.primary
                                : AppColors.error,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              showOnHome ? 'Home ON' : 'Hidden',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: showOnHome
                                    ? AppColors.primary
                                    : AppColors.error,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 13,
                            decoration: BoxDecoration(
                              color: showOnHome
                                  ? AppColors.primary
                                  : AppColors.error.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  left: showOnHome ? 12 : 1,
                                  top: 1,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiBox(String catName) => Container(
    color: AppColors.primary.withOpacity(0.08),
    child: Center(
      child: Text(_emoji(catName), style: const TextStyle(fontSize: 38)),
    ),
  );

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
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

  // ── Add Sweets Category Manually ──────────────────────────
  void _showAddSweetsCategoryDialog() {
    final ctrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
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
              const SizedBox(height: 20),
              const Text(
                '🍬 Add Sweet Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ye category sweets tab mein dikhegi',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Cakes, Pastries, Gulab Jamun...',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = ctrl.text.trim();
                          if (name.isEmpty) {
                            _snack('Category name daalo!', isError: true);
                            return;
                          }
                          if (_sweetsCategories
                              .map((c) => c.toLowerCase())
                              .contains(name.toLowerCase())) {
                            _snack('Ye category pehle se hai!', isError: true);
                            return;
                          }
                          setModal(() => isSaving = true);
                          try {
                            await _supabase.from('food_categories').insert({
                              'name': name,
                              'image_url': null,
                              'sort_order': _sweetsCategories.length,
                              'is_active': true,
                              'is_show_on_home': true,
                              'category_type': 'sweets',
                            });
                            await _loadData();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack('$name add ho gayi ✅');
                          } catch (e) {
                            setModal(() => isSaving = false);
                            _snack('Error: $e', isError: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add Karo ✅',
                          style: TextStyle(
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
    ).whenComplete(() => ctrl.dispose());
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
              Icons.category_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Is tab mein categories nahi hain',
            style: AppStyles.sectionHeader,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vendors add karo with categories — wahan se auto aayengi',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildAllVisibleState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Saari Categories Visible Hain!',
            style: AppStyles.sectionHeader,
          ),
          const SizedBox(height: 8),
          const Text(
            'Koi bhi category hidden nahi hai abhi.',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _showOnlyHidden = false),
            child: const Text(
              'Saari categories dekho',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
