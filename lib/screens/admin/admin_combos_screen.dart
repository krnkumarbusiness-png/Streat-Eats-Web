import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/combo_model.dart';
import '../../services/combo_service.dart';

class AdminCombosScreen extends StatefulWidget {
  const AdminCombosScreen({super.key});

  @override
  State<AdminCombosScreen> createState() => _AdminCombosScreenState();
}

class _AdminCombosScreenState extends State<AdminCombosScreen> {
  final _comboService = ComboService();
  File? _selectedImageFile;
  String? _existingImageUrl;
  // ignore: unused_field
  final bool _isUploading = false;
  final _supabase = Supabase.instance.client;
  List<ComboModel> _combos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final combos = await _comboService.getAllCombosAdmin();
    if (mounted) {
      setState(() {
        _combos = combos;
        _isLoading = false;
      });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showAddEditDialog([ComboModel? existing]) async {
    // Fetch vendors for dropdown
    List<Map<String, dynamic>> vendors = [];
    try {
      final data = await _supabase
          .from('vendors')
          .select('id, name, area')
          .eq('city', 'Haldwani')
          .order('name');
      vendors = List<Map<String, dynamic>>.from(data);
    } catch (_) {}

    if (!mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final vendorPriceCtrl = TextEditingController(
      text: existing?.vendorPrice.toStringAsFixed(0) ?? '',
    );
    final appPriceCtrl = TextEditingController(
      text: existing?.appPrice.toStringAsFixed(0) ?? '',
    );
    final originalPriceCtrl = TextEditingController(
      text: existing?.originalPrice?.toStringAsFixed(0) ?? '',
    );
    _selectedImageFile = null;
    _existingImageUrl = existing?.imageUrl;
    final itemsCtrl = TextEditingController(
      text: existing?.itemsIncluded ?? '',
    );
    final sortCtrl = TextEditingController(
      text: existing?.sortOrder.toString() ?? '0',
    );

    String? selectedVendorId = existing?.vendorId;
    bool isDiscounted = existing?.isDiscounted ?? false;
    bool isAvailable = existing?.isAvailable ?? true;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
          builder: (ctx, setDState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                        Icons.local_offer_rounded,
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
                            existing == null
                                ? 'Combo Add Karo'
                                : 'Combo Edit Karo',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            selectedVendorId == null
                                ? 'Vendor select karo neeche'
                                : vendors.firstWhere(
                                        (v) => v['id'] == selectedVendorId,
                                        orElse: () => {'name': ''},
                                      )['name'] ??
                                      '',
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

                // Vendor Section
                _formLabel('Vendor', 'Kis vendor ka combo hai?'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedVendorId,
                      isExpanded: true,
                      hint: const Text(
                        'Vendor choose karo',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      dropdownColor: AppColors.surface,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                      items: vendors
                          .map(
                            (v) => DropdownMenuItem(
                              value: v['id'] as String,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.store_rounded,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${v['name']} · ${v['area']}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDState(() => selectedVendorId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Image Picker
                _formLabel('Combo Photo', 'Customer ko yahi dikhegi'),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (_, setImg) => GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked == null) return;
                      final original = File(picked.path);
                      final compressed =
                          await FlutterImageCompress.compressAndGetFile(
                            original.path,
                            '${original.parent.path}/combo_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            quality: 70,
                            minWidth: 400,
                            minHeight: 400,
                            format: CompressFormat.jpeg,
                          );
                      setImg(
                        () => _selectedImageFile = File(
                          compressed?.path ?? original.path,
                        ),
                      );
                      setDState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedImageFile != null
                              ? AppColors.primary
                              : AppColors.border,
                          width: _selectedImageFile != null ? 2 : 1,
                        ),
                      ),
                      child: _selectedImageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _existingImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _existingImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder(),
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                          : _imgPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Basic Info
                _formLabel('Combo Details', 'Naam aur description'),
                const SizedBox(height: 8),
                _field(
                  nameCtrl,
                  'Combo ka naam (e.g. Momo Meal Deal)',
                  Icons.fastfood_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  descCtrl,
                  'Short description (menu card pe dikhega)',
                  Icons.notes_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  itemsCtrl,
                  'Items included (comma separated)',
                  Icons.list_rounded,
                ),
                const SizedBox(height: 16),

                // Pricing Section
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
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.warning,
                            size: 12,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              vendorPriceCtrl,
                              'Vendor Cost (₹)',
                              Icons.money_off_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              appPriceCtrl,
                              'App Price (₹)',
                              Icons.sell_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Discount Section
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
                                    fontFamily: 'Poppins',
                                    color: isDiscounted
                                        ? AppColors.error
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _comboToggle(
                            isDiscounted,
                            AppColors.error,
                            () => setDState(() => isDiscounted = !isDiscounted),
                          ),
                        ],
                      ),
                      if (isDiscounted) ...[
                        const SizedBox(height: 12),
                        _field(
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

                // Sort Order
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        sortCtrl,
                        'Sort Order (0 = pehle)',
                        Icons.sort_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Available toggle
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.success.withOpacity(0.04)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAvailable
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAvailable ? 'Available ✅' : 'Unavailable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                      color: isAvailable
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _comboToggle(
                              isAvailable,
                              AppColors.success,
                              () => setDState(() => isAvailable = !isAvailable),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (selectedVendorId == null ||
                                nameCtrl.text.trim().isEmpty ||
                                appPriceCtrl.text.trim().isEmpty ||
                                vendorPriceCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Fill all required fields',
                                    style: TextStyle(fontFamily: 'Poppins'),
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            setDState(() => isSaving = true);
                            String? finalImageUrl = _existingImageUrl;
                            if (_selectedImageFile != null) {
                              final url = await StorageService().uploadImage(
                                _selectedImageFile!,
                                folder: 'combos',
                              );
                              if (url == null) {
                                setDState(() => isSaving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Image upload failed'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              finalImageUrl = url;
                            }
                            final payload = {
                              'vendor_id': selectedVendorId,
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'items_included': itemsCtrl.text.trim(),
                              'vendor_price':
                                  double.tryParse(
                                    vendorPriceCtrl.text.trim(),
                                  ) ??
                                  0,
                              'app_price':
                                  double.tryParse(appPriceCtrl.text.trim()) ??
                                  0,
                              'original_price':
                                  originalPriceCtrl.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(
                                      originalPriceCtrl.text.trim(),
                                    ),
                              'image_url': finalImageUrl,
                              'is_discounted': isDiscounted,
                              'is_available': isAvailable,
                              'sort_order':
                                  int.tryParse(sortCtrl.text.trim()) ?? 0,
                            };
                            bool ok;
                            if (existing == null) {
                              ok = await _comboService.createCombo(payload);
                            } else {
                              ok = await _comboService.updateCombo(
                                existing.id,
                                payload,
                              );
                            }
                            setDState(() => isSaving = false);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack(
                              ok
                                  ? (existing == null
                                        ? 'Combo created! ✅'
                                        : 'Combo updated! ✅')
                                  : 'Failed. Try again.',
                              isError: !ok,
                            );
                            if (ok) _load();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.5,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving
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
                            existing == null ? 'Combo Add Karo' : 'Update Karo',
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

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
      decoration: _inputDec(hint, icon),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      color: AppColors.textMuted,
    ),
    prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Manage Combos', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Combo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _combos.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _combos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildComboCard(_combos[i]),
              ),
            ),
    );
  }

  Widget _buildComboCard(ComboModel combo) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    combo.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Available toggle
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: combo.isAvailable,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) async {
                      final ok = await _comboService.toggleAvailability(
                        combo.id,
                        val,
                      );
                      if (ok) {
                        _load();
                      } else {
                        _snack('Failed to update', isError: true);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (combo.description.isNotEmpty)
              Text(
                combo.description,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Vendor price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Vendor: ₹${combo.vendorPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // App price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'App: ₹${combo.appPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (combo.isDiscounted && combo.discountPercent > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${combo.discountPercent}% OFF',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Edit
                GestureDetector(
                  onTap: () => _showAddEditDialog(combo),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text(
                          'Delete Combo?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to delete "${combo.name}"?',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.textMuted,
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
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final ok = await _comboService.deleteCombo(combo.id);
                    _snack(ok ? 'Combo deleted!' : 'Failed', isError: !ok);
                    if (ok) _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🎁', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text(
          'No combos yet',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap + to create your first combo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
  Widget _formLabel(String title, String subtitle) {
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

  Widget _comboToggle(bool value, Color activeColor, VoidCallback onTap) {
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

  Widget _imgPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.add_photo_alternate_outlined,
        color: AppColors.primary.withOpacity(0.4),
        size: 32,
      ),
      const SizedBox(height: 6),
      const Text(
        'Photo add karo',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontFamily: 'Poppins',
        ),
      ),
    ],
  );
}
