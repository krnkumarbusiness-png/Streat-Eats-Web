import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../services/storage_service.dart';

// ================================================================
// FILE: lib/screens/admin/admin_settings_screen.dart
// v3.0 — Tabbed Layout (4 tabs) + Packaging Fee + Dog Donation
// Tab 1: Delivery & Fees  (Zone + Platform Fee + Delivery Charges)
// Tab 2: Packaging Fee    (Slab based, admin controlled)
// Tab 3: Dog Donation     (Counter, popup, image, frequency)
// Tab 4: App Timing       (Open/Close hours)
// ================================================================

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // ── Tab 1: Platform Fee ──────────────────────────────────
  final _platformFeeCtrl = TextEditingController();

  // ── Tab 1: Delivery charges ──────────────────────────────
  final _charge01Ctrl = TextEditingController();
  final _charge12Ctrl = TextEditingController();
  final _charge23Ctrl = TextEditingController();
  final _charge34Ctrl = TextEditingController();
  final _charge45Ctrl = TextEditingController();
  final _charge5kmBaseCtrl = TextEditingController();
  final _chargePerKmAfter5Ctrl = TextEditingController();

  // ── Tab 1: Delivery zone ─────────────────────────────────
  final _centerLatCtrl = TextEditingController();
  final _centerLngCtrl = TextEditingController();
  final _radiusKmCtrl = TextEditingController();

  // ── Tab 2: Packaging Fee slabs ───────────────────────────
  final _pkg0to99Ctrl = TextEditingController();
  final _pkg100to199Ctrl = TextEditingController();
  final _pkg200plusCtrl = TextEditingController();
  bool _packagingEnabled = true;

  // ── Tab 3: Dog Donation ──────────────────────────────────
  final _dogsFedCtrl = TextEditingController();
  final _totalDonationCtrl = TextEditingController();
  final _popupFrequencyCtrl = TextEditingController();
  final _donationPageTitleCtrl = TextEditingController();
  final _donationPageSubtitleCtrl = TextEditingController();
  bool _donationPopupEnabled = true;
  String? _popupImageUrl;
  bool _isUploadingPopupImage = false;

  // ── Tab 4: App Timing ────────────────────────────────────
  bool _isTimingEnabled = true;
  bool _showUpsellSuggestions = true;
  TimeOfDay _openTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  // Multiple time slots
  List<Map<String, dynamic>> _timeSlots = [
    {'label': 'Evening', 'open': '17:00', 'close': '21:00', 'enabled': true},
  ];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _settingsId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _platformFeeCtrl.dispose();
    _charge01Ctrl.dispose();
    _charge12Ctrl.dispose();
    _charge23Ctrl.dispose();
    _charge34Ctrl.dispose();
    _charge45Ctrl.dispose();
    _charge5kmBaseCtrl.dispose();
    _chargePerKmAfter5Ctrl.dispose();
    _centerLatCtrl.dispose();
    _centerLngCtrl.dispose();
    _radiusKmCtrl.dispose();
    _pkg0to99Ctrl.dispose();
    _pkg100to199Ctrl.dispose();
    _pkg200plusCtrl.dispose();
    _dogsFedCtrl.dispose();
    _totalDonationCtrl.dispose();
    _popupFrequencyCtrl.dispose();
    _donationPageTitleCtrl.dispose();
    _donationPageSubtitleCtrl.dispose();
    super.dispose();
  }

  // ── Load Settings ─────────────────────────────────────────────
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('app_settings')
          .select()
          .limit(1)
          .maybeSingle();
      if (data == null) {
        await _createDefaultSettings();
        return;
      }
      _applyData(data);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Settings load failed — using defaults', isError: true);
        _applyDefaults();
      }
    }
  }

  Future<void> _createDefaultSettings() async {
    try {
      final inserted = await _supabase
          .from('app_settings')
          .insert({
            'platform_fee': 5,
            'delivery_charge_0_1': 0,
            'delivery_charge_1_2': 10,
            'delivery_charge_2_3': 20,
            'delivery_charge_3_4': 30,
            'delivery_charge_4_5': 40,
            'delivery_charge_5km_base': 70,
            'delivery_charge_per_km_after_5': 10,
            'delivery_center_lat': 29.2183,
            'delivery_center_lng': 79.5130,
            'delivery_radius_km': 15.0,
            'is_timing_enabled': true,
            'open_time': '17:00',
            'close_time': '21:00',
            'show_upsell_suggestions': true,
            // Packaging fee defaults
            'packaging_enabled': true,
            'packaging_fee_0_99': 2,
            'packaging_fee_100_199': 5,
            'packaging_fee_200_plus': 8,
            // Dog donation defaults
            'donation_popup_enabled': true,
            'donation_dogs_fed': 0,
            'donation_total_raised': 0,
            'donation_popup_frequency_hours': 24,
            'donation_popup_image_url': null,
            'donation_title': 'Feed a Street Dog Today 🐶',
            'donation_subtitle':
                'Tumhara ek chhota sa kadam, ek puche ki bhari pet!',
          })
          .select()
          .single();
      if (mounted) _applyData(inserted);
    } catch (e) {
      if (mounted) {
        _applyDefaults();
        _snack('app_settings table missing — SQL run karo!', isError: true);
      }
    }
  }

  void _applyData(Map<String, dynamic> data) {
    _settingsId = data['id']?.toString();

    // Tab 1 — Delivery & Fees
    _platformFeeCtrl.text = (data['platform_fee'] ?? 5).toString();
    _charge01Ctrl.text = (data['delivery_charge_0_1'] ?? 0).toString();
    _charge12Ctrl.text = (data['delivery_charge_1_2'] ?? 10).toString();
    _charge23Ctrl.text = (data['delivery_charge_2_3'] ?? 20).toString();
    _charge34Ctrl.text = (data['delivery_charge_3_4'] ?? 30).toString();
    _charge45Ctrl.text = (data['delivery_charge_4_5'] ?? 40).toString();
    _charge5kmBaseCtrl.text = (data['delivery_charge_5km_base'] ?? 70)
        .toString();
    _chargePerKmAfter5Ctrl.text = (data['delivery_charge_per_km_after_5'] ?? 10)
        .toString();
    _centerLatCtrl.text = (data['delivery_center_lat'] ?? 29.2183).toString();
    _centerLngCtrl.text = (data['delivery_center_lng'] ?? 79.5130).toString();
    _radiusKmCtrl.text = (data['delivery_radius_km'] ?? 15.0).toString();

    // Tab 2 — Packaging Fee
    _packagingEnabled = data['packaging_enabled'] as bool? ?? true;
    _pkg0to99Ctrl.text = (data['packaging_fee_0_99'] ?? 2).toString();
    _pkg100to199Ctrl.text = (data['packaging_fee_100_199'] ?? 5).toString();
    _pkg200plusCtrl.text = (data['packaging_fee_200_plus'] ?? 8).toString();

    // Tab 3 — Dog Donation
    _donationPopupEnabled = data['donation_popup_enabled'] as bool? ?? true;
    _dogsFedCtrl.text = (data['donation_dogs_fed'] ?? 0).toString();
    _totalDonationCtrl.text = (data['donation_total_raised'] ?? 0).toString();
    _popupFrequencyCtrl.text = (data['donation_popup_frequency_hours'] ?? 24)
        .toString();
    _popupImageUrl = data['donation_popup_image_url'] as String?;
    _donationPageTitleCtrl.text =
        data['donation_title'] as String? ?? 'Feed a Street Dog Today 🐶';
    _donationPageSubtitleCtrl.text =
        data['donation_subtitle'] as String? ??
        'Tumhara ek chhota sa kadam, ek puche ki bhari pet!';

    // Tab 4 — Timing
    _isTimingEnabled = data['is_timing_enabled'] as bool? ?? true;
    _showUpsellSuggestions = data['show_upsell_suggestions'] as bool? ?? true;
    try {
      final openStr = data['open_time'] as String? ?? '17:00';
      final closeStr = data['close_time'] as String? ?? '21:00';
      final op = openStr.split(':');
      final cl = closeStr.split(':');
      _openTime = TimeOfDay(hour: int.parse(op[0]), minute: int.parse(op[1]));
      _closeTime = TimeOfDay(hour: int.parse(cl[0]), minute: int.parse(cl[1]));
    } catch (_) {
      _openTime = const TimeOfDay(hour: 17, minute: 0);
      _closeTime = const TimeOfDay(hour: 21, minute: 0);
    }

    // Time slots load karo
    try {
      final slotsRaw = data['time_slots'];
      if (slotsRaw != null && (slotsRaw as List).isNotEmpty) {
        _timeSlots = (slotsRaw)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  void _applyDefaults() {
    _platformFeeCtrl.text = '5';
    _charge01Ctrl.text = '0';
    _charge12Ctrl.text = '10';
    _charge23Ctrl.text = '20';
    _charge34Ctrl.text = '30';
    _charge45Ctrl.text = '40';
    _charge5kmBaseCtrl.text = '70';
    _chargePerKmAfter5Ctrl.text = '10';
    _centerLatCtrl.text = '29.2183';
    _centerLngCtrl.text = '79.5130';
    _radiusKmCtrl.text = '15.0';
    _packagingEnabled = true;
    _pkg0to99Ctrl.text = '2';
    _pkg100to199Ctrl.text = '5';
    _pkg200plusCtrl.text = '8';
    _donationPopupEnabled = true;
    _dogsFedCtrl.text = '0';
    _totalDonationCtrl.text = '0';
    _popupFrequencyCtrl.text = '24';
    _donationPageTitleCtrl.text = 'Feed a Street Dog Today 🐶';
    _donationPageSubtitleCtrl.text =
        'Tumhara ek chhota sa kadam, ek puche ki bhari pet!';
    _isTimingEnabled = true;
    _showUpsellSuggestions = true;
    _openTime = const TimeOfDay(hour: 17, minute: 0);
    _closeTime = const TimeOfDay(hour: 21, minute: 0);
    setState(() => _isLoading = false);
  }

  // ── Save All Settings ─────────────────────────────────────────
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final openStr =
          '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}';
      final closeStr =
          '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}';

      final payload = {
        // Tab 1
        'platform_fee': double.tryParse(_platformFeeCtrl.text) ?? 5,
        'delivery_charge_0_1': double.tryParse(_charge01Ctrl.text) ?? 0,
        'delivery_charge_1_2': double.tryParse(_charge12Ctrl.text) ?? 10,
        'delivery_charge_2_3': double.tryParse(_charge23Ctrl.text) ?? 20,
        'delivery_charge_3_4': double.tryParse(_charge34Ctrl.text) ?? 30,
        'delivery_charge_4_5': double.tryParse(_charge45Ctrl.text) ?? 40,
        'delivery_charge_5km_base':
            double.tryParse(_charge5kmBaseCtrl.text) ?? 70,
        'delivery_charge_per_km_after_5':
            double.tryParse(_chargePerKmAfter5Ctrl.text) ?? 10,
        'delivery_center_lat': double.tryParse(_centerLatCtrl.text) ?? 29.2183,
        'delivery_center_lng': double.tryParse(_centerLngCtrl.text) ?? 79.5130,
        'delivery_radius_km': double.tryParse(_radiusKmCtrl.text) ?? 15.0,
        // Tab 2
        'packaging_enabled': _packagingEnabled,
        'packaging_fee_0_99': double.tryParse(_pkg0to99Ctrl.text) ?? 2,
        'packaging_fee_100_199': double.tryParse(_pkg100to199Ctrl.text) ?? 5,
        'packaging_fee_200_plus': double.tryParse(_pkg200plusCtrl.text) ?? 8,
        // Tab 3
        'donation_popup_enabled': _donationPopupEnabled,
        'donation_dogs_fed': int.tryParse(_dogsFedCtrl.text) ?? 0,
        'donation_total_raised': double.tryParse(_totalDonationCtrl.text) ?? 0,
        'donation_popup_frequency_hours':
            int.tryParse(_popupFrequencyCtrl.text) ?? 24,
        'donation_popup_image_url': _popupImageUrl,
        'donation_title': _donationPageTitleCtrl.text.trim(),
        'donation_subtitle': _donationPageSubtitleCtrl.text.trim(),
        // Tab 4
        'is_timing_enabled': _isTimingEnabled,
        'show_upsell_suggestions': _showUpsellSuggestions,
        'open_time': openStr,
        'close_time': closeStr,
        'time_slots': _timeSlots,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_settingsId != null) {
        await _supabase
            .from('app_settings')
            .update(payload)
            .eq('id', _settingsId!);
      } else {
        final inserted = await _supabase
            .from('app_settings')
            .insert(payload)
            .select()
            .single();
        _settingsId = inserted['id']?.toString();
      }

      _snack('Settings saved! ✅');
    } catch (e) {
      _snack('Save failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Upload Popup Image ────────────────────────────────────────
  Future<void> _uploadPopupImage() async {
    if (_isUploadingPopupImage) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPopupImage = true);
    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      // StorageService use karo — same as menu items
      final storageService = StorageService();
      final url = await storageService.uploadImage(
        file,
        folder: 'donation-popup', // R2 mein yahi folder banega
      );

      if (url == null) {
        _snack('Image upload failed', isError: true);
        return;
      }

      setState(() => _popupImageUrl = url);
      _snack('Popup image uploaded! ✅');
    } catch (e) {
      _snack('Image upload failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPopupImage = false);
    }
  }

  // ── Time Picker ───────────────────────────────────────────────
  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isOpen ? _openTime = picked : _closeTime = picked);
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
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _chargePreview(double distKm) {
    final base = double.tryParse(_charge5kmBaseCtrl.text) ?? 70;
    final perKm = double.tryParse(_chargePerKmAfter5Ctrl.text) ?? 10;
    final extra = distKm - 5.0;
    final total = base + (extra * perKm);
    return '₹${total.toStringAsFixed(0)}';
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Settings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadSettings,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            tooltip: 'Reload',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.border),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: '🚚 Delivery & Fees'),
                  Tab(text: '📦 Packaging'),
                  Tab(text: '🐶 Dog Donation'),
                  Tab(text: '⏰ Timing'),
                ],
              ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _tab1DeliveryFees(),
                _tab2Packaging(),
                _tab3DogDonation(),
                _tab4Timing(),
              ],
            ),
      // ── Floating Save Button ────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSettings,
        backgroundColor: _isSaving
            ? AppColors.primary.withOpacity(0.5)
            : AppColors.primary,
        elevation: 4,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
        label: Text(
          _isSaving ? 'Saving...' : 'Save All',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TAB 1 — DELIVERY & FEES
  // ════════════════════════════════════════════════════════════
  Widget _tab1DeliveryFees() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_settingsId == null) _warningBanner(),

          // ── Platform Fee ──────────────────────────────────
          _sectionHeader(
            icon: Icons.payments_outlined,
            title: 'Platform Fee',
            subtitle: 'Charged per order from customer',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Platform Fee (₹)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _inlineField(
                        ctrl: _platformFeeCtrl,
                        hint: '5',
                        prefix: '₹ ',
                        large: true,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'per order',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Delivery Zone ─────────────────────────────────
          _sectionHeader(
            icon: Icons.my_location_rounded,
            title: 'Delivery Zone',
            subtitle: 'Radius ke bahar ke user block ho jayenge',
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          _card(
            borderColor: const Color(0xFF2563EB).withOpacity(0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoBanner(
                  icon: '📍',
                  text:
                      'Haldwani center ka lat/lng daalo. 15km radius recommend hai.',
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _labeledField(
                        label: 'Center Latitude',
                        ctrl: _centerLatCtrl,
                        hint: '29.2183',
                        helper: 'Haldwani: 29.2183',
                        isDecimal: true,
                        allowNegative: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _labeledField(
                        label: 'Center Longitude',
                        ctrl: _centerLngCtrl,
                        hint: '79.5130',
                        helper: 'Haldwani: 79.5130',
                        isDecimal: true,
                        allowNegative: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _labeledField(
                  label: 'Delivery Radius (km)',
                  ctrl: _radiusKmCtrl,
                  hint: '15',
                  helper: 'Is radius ke andar order allow hoga',
                  isDecimal: true,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _centerLatCtrl.text = '29.2183';
                      _centerLngCtrl.text = '79.5130';
                      _radiusKmCtrl.text = '15';
                    });
                    _snack('Haldwani defaults set! ✅');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withOpacity(0.25),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_city_rounded,
                          color: Color(0xFF2563EB),
                          size: 14,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Use Haldwani Defaults (29.2183, 79.5130 — 15km)',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 11,
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

          const SizedBox(height: 20),

          // ── Delivery Charges ──────────────────────────────
          _sectionHeader(
            icon: Icons.delivery_dining_rounded,
            title: 'Delivery Charges',
            subtitle: 'Distance based slabs (hidden in food price)',
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              children: [
                _chargeRow('0 – 1 km', _charge01Ctrl, '0'),
                _slabDivider(),
                _chargeRow('1 – 2 km', _charge12Ctrl, '10'),
                _slabDivider(),
                _chargeRow('2 – 3 km', _charge23Ctrl, '20'),
                _slabDivider(),
                _chargeRow('3 – 4 km', _charge34Ctrl, '30'),
                _slabDivider(),
                _chargeRow('4 – 5 km', _charge45Ctrl, '40'),
                _slabDivider(),
                const SizedBox(height: 8),
                // 5km+ formula box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
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
                            Icons.local_shipping_outlined,
                            color: AppColors.primary,
                            size: 13,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '5 km+ Formula',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Total = Base + (Extra km × Per km rate)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _miniLabelField(
                              label: 'Base Charge (₹)',
                              ctrl: _charge5kmBaseCtrl,
                              hint: '70',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: Text(
                              ' + ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _miniLabelField(
                              label: 'Per km Rate (₹)',
                              ctrl: _chargePerKmAfter5Ctrl,
                              hint: '10',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _previewPill('6 km', _chargePreview(6)),
                            _previewPill('8 km', _chargePreview(8)),
                            _previewPill('10 km', _chargePreview(10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sqlHelperCard(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TAB 2 — PACKAGING FEE
  // ════════════════════════════════════════════════════════════
  Widget _tab2Packaging() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Enable Toggle ─────────────────────────────────
          _card(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Packaging Fee',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Cart total ke basis pe calculate hoga',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _packagingEnabled,
                  onChanged: (v) => setState(() => _packagingEnabled = v),
                  activeThumbColor: const Color(0xFF7C3AED),
                  activeTrackColor: const Color(0xFF7C3AED).withOpacity(0.3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (!_packagingEnabled)
            _card(
              child: _infoBanner(
                icon: '🔕',
                text:
                    'Packaging fee OFF hai. Customer se packaging charge nahi liya jayega.',
                color: AppColors.textMuted,
              ),
            )
          else ...[
            // ── How it works ──────────────────────────────
            _card(
              borderColor: const Color(0xFF7C3AED).withOpacity(0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoBanner(
                    icon: '💡',
                    text:
                        'Cart total ke hisaab se packaging fee automatically add hoti hai — cart, checkout aur order summary mein dikti hai.',
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 16),

                  // Slab 1: ₹0–99
                  _packagingSlabCard(
                    range: '₹0 – ₹99',
                    rangeSubtitle: 'Chhote orders',
                    emoji: '📦',
                    ctrl: _pkg0to99Ctrl,
                    hint: '2',
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 10),

                  // Slab 2: ₹100–199
                  _packagingSlabCard(
                    range: '₹100 – ₹199',
                    rangeSubtitle: 'Medium orders',
                    emoji: '🗃️',
                    ctrl: _pkg100to199Ctrl,
                    hint: '5',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 10),

                  // Slab 3: ₹200+
                  _packagingSlabCard(
                    range: '₹200+',
                    rangeSubtitle: 'Bade orders',
                    emoji: '📫',
                    ctrl: _pkg200plusCtrl,
                    hint: '8',
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: 16),

                  // Live preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Preview:',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _pkgPreviewRow(
                          'Order ₹80',
                          '₹${_pkg0to99Ctrl.text.isEmpty ? "2" : _pkg0to99Ctrl.text} packaging',
                        ),
                        _pkgPreviewRow(
                          'Order ₹150',
                          '₹${_pkg100to199Ctrl.text.isEmpty ? "5" : _pkg100to199Ctrl.text} packaging',
                        ),
                        _pkgPreviewRow(
                          'Order ₹250',
                          '₹${_pkg200plusCtrl.text.isEmpty ? "8" : _pkg200plusCtrl.text} packaging',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // SQL card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Supabase SQL — Packaging Columns',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    const sql =
                        "ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS packaging_enabled BOOLEAN DEFAULT true;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS packaging_fee_0_99 DOUBLE PRECISION DEFAULT 2;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS packaging_fee_100_199 DOUBLE PRECISION DEFAULT 5;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS packaging_fee_200_plus DOUBLE PRECISION DEFAULT 8;";
                    Clipboard.setData(const ClipboardData(text: sql));
                    _snack('SQL copied! Supabase mein paste karo ✅');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ALTER TABLE app_settings ADD COLUMN packaging_enabled... — tap to copy',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.primary,
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
    );
  }

  // ════════════════════════════════════════════════════════════
  // TAB 3 — DOG DONATION
  // ════════════════════════════════════════════════════════════
  Widget _tab3DogDonation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  const Color(0xFFEF4444).withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Text('🐾', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dog Donation Module',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Popup, stats aur donation page — sab yahan se control karo',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Stats Section ─────────────────────────────────
          _sectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Stats Counter',
            subtitle: 'Manually set karo — app mein dikhega',
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              children: [
                Row(
                  children: [
                    // Dogs Fed
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF97316).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text('🐶', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 6),
                            const Text(
                              'Dogs Fed',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _dogsFedCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 22,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total Donation
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text('💚', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 6),
                            const Text(
                              'Total Donated (₹)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _totalDonationCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 22,
                                  fontFamily: 'Poppins',
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
                _infoBanner(
                  icon: '✏️',
                  text:
                      'Ye stats DonationScreen ke top mein real time dikhte hain. Manually update karo jab chaaho.',
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Popup Settings ────────────────────────────────
          _sectionHeader(
            icon: Icons.campaign_rounded,
            title: 'Home Screen Popup',
            subtitle: 'Admin se control, SharedPreferences se track',
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Popup on/off toggle
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popup Active',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Home screen pe popup dikhega',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _donationPopupEnabled,
                      onChanged: (v) =>
                          setState(() => _donationPopupEnabled = v),
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.border),
                const SizedBox(height: 14),

                // Frequency field
                _labeledField(
                  label: 'Popup Frequency (hours)',
                  ctrl: _popupFrequencyCtrl,
                  hint: '24',
                  helper: 'Kitne ghante baad dobara dikhega — e.g. 24 = daily',
                ),

                const SizedBox(height: 16),

                // Popup image upload
                const Text(
                  'Popup Banner Image',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isUploadingPopupImage ? null : _uploadPopupImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _popupImageUrl != null
                            ? AppColors.primary.withOpacity(0.4)
                            : AppColors.border,
                        width: _popupImageUrl != null ? 1.5 : 1,
                      ),
                    ),
                    child: _isUploadingPopupImage
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : _popupImageUrl != null && _popupImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Stack(
                              children: [
                                Image.network(
                                  _popupImageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _uploadPlaceholder(),
                                ),
                                // Overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Change Image',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _uploadPlaceholder(),
                  ),
                ),
                if (_popupImageUrl != null && _popupImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _popupImageUrl = null),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Remove image',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Donation Page Content ─────────────────────────
          _sectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'Donation Page Content',
            subtitle: 'DonationScreen ka title aur subtitle manage karo',
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              children: [
                _labeledField(
                  label: 'Page Title',
                  ctrl: _donationPageTitleCtrl,
                  hint: 'Feed a Street Dog Today 🐶',
                  helper: 'DonationScreen ka main heading',
                ),
                const SizedBox(height: 12),
                _labeledField(
                  label: 'Page Subtitle',
                  ctrl: _donationPageSubtitleCtrl,
                  hint: 'Tumhara ek chhota sa kadam...',
                  helper: 'Title ke neeche wala text',
                  maxLines: 2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // SQL
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Supabase SQL — Dog Donation Columns',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    const sql =
                        "ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_popup_enabled BOOLEAN DEFAULT true;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_dogs_fed INTEGER DEFAULT 0;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_total_amount DOUBLE PRECISION DEFAULT 0;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_popup_frequency_hours INTEGER DEFAULT 24;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_popup_image_url TEXT;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_page_title TEXT DEFAULT 'Feed a Street Dog Today 🐶';\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS donation_page_subtitle TEXT DEFAULT 'Tumhara ek chhota sa kadam, ek puche ki bhari pet!';";
                    Clipboard.setData(const ClipboardData(text: sql));
                    _snack('SQL copied! ✅');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ALTER TABLE app_settings ADD COLUMN donation_popup_enabled... — tap to copy',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.primary,
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
    );
  }

  // ════════════════════════════════════════════════════════════
  // TAB 4 — APP TIMING
  // ════════════════════════════════════════════════════════════
  Widget _tab4Timing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timing Toggle ─────────────────────────────────
          _card(
            borderColor: _isTimingEnabled
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.border,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timing Restriction',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isTimingEnabled
                                ? 'App opens only at set hours'
                                : 'App is open all day (24/7)',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              color: _isTimingEnabled
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isTimingEnabled,
                      onChanged: (v) => setState(() => _isTimingEnabled = v),
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ],
                ),
                if (_isTimingEnabled) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),
                  // ── Multiple Time Slots UI ──────────────
                  ..._timeSlots.asMap().entries.map((entry) {
                    final i = entry.key;
                    final slot = entry.value;
                    final enabled = slot['enabled'] as bool? ?? true;
                    final openStr = slot['open'] as String? ?? '17:00';
                    final closeStr = slot['close'] as String? ?? '21:00';
                    final label = slot['label'] as String? ?? 'Slot ${i + 1}';

                    final openParts = openStr.split(':');
                    final closeParts = closeStr.split(':');
                    final openTod = TimeOfDay(
                      hour: int.parse(openParts[0]),
                      minute: int.parse(openParts[1]),
                    );
                    final closeTod = TimeOfDay(
                      hour: int.parse(closeParts[0]),
                      minute: int.parse(closeParts[1]),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: enabled
                              ? AppColors.primary.withOpacity(0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(text: label)
                                    ..selection = TextSelection.collapsed(
                                      offset: label.length,
                                    ),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Slot name',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (v) => setState(
                                    () => _timeSlots[i]['label'] = v,
                                  ),
                                ),
                              ),
                              Switch(
                                value: enabled,
                                onChanged: (v) => setState(
                                  () => _timeSlots[i]['enabled'] = v,
                                ),
                                activeThumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                              if (_timeSlots.length > 1)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _timeSlots.removeAt(i)),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _timePicker(
                                  label: 'Opens At',
                                  time: openTod,
                                  icon: Icons.wb_sunny_outlined,
                                  color: AppColors.warning,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: openTod,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _timeSlots[i]['open'] =
                                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _timePicker(
                                  label: 'Closes At',
                                  time: closeTod,
                                  icon: Icons.nights_stay_outlined,
                                  color: AppColors.primary,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: closeTod,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _timeSlots[i]['close'] =
                                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Slot Button
                  GestureDetector(
                    onTap: () => setState(() {
                      _timeSlots.add({
                        'label': 'Slot ${_timeSlots.length + 1}',
                        'open': '10:00',
                        'close': '12:00',
                        'enabled': true,
                      });
                    }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add Another Time Slot',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2),
                      ),
                    ),
                    child: const Text(
                      'App will be open 24/7',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Upsell Toggle ─────────────────────────────────
          _sectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Upsell Suggestions',
            subtitle: '"Yeh bhi try karo" suggestions on/off',
          ),
          const SizedBox(height: 12),
          _card(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show Upsell Suggestions',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Cart aur checkout pe related items suggest karo',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showUpsellSuggestions,
                  onChanged: (v) => setState(() => _showUpsellSuggestions = v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withOpacity(0.3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Info card ─────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'How timing works',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoPoint(
                  '5 PM se 9 PM ke beech hi app orders accept karega.',
                ),
                _infoPoint('Bahar aane pe "Abhi Band Hai 🔒" screen dikhegi.'),
                _infoPoint(
                  'Is screen pe countdown timer hoga kitne baje khulega.',
                ),
                _infoPoint(
                  'Timing restriction OFF karne pe app 24/7 khula rahega — testing ke liye use karo.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _card({required Widget child, Color? borderColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: AppColors.textPrimary,
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

  Widget _labeledField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    String? helper,
    bool isDecimal = false,
    bool allowNegative = false,
    int maxLines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: maxLines > 1
            ? TextInputType.multiline
            : TextInputType.numberWithOptions(
                decimal: isDecimal,
                signed: allowNegative,
              ),
        inputFormatters: maxLines > 1
            ? []
            : allowNegative
            ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))]
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        maxLines: maxLines,
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
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
          helperText: helper,
          helperStyle: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontFamily: 'Poppins',
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          isDense: true,
        ),
      ),
    ],
  );

  Widget _inlineField({
    required TextEditingController ctrl,
    required String hint,
    String? prefix,
    bool large = false,
  }) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
    ],
    style: TextStyle(
      color: AppColors.textPrimary,
      fontSize: large ? 22 : 14,
      fontWeight: FontWeight.w700,
      fontFamily: 'Poppins',
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: large ? 22 : 14,
        fontFamily: 'Poppins',
      ),
      prefixText: prefix,
      prefixStyle: TextStyle(
        color: AppColors.primary,
        fontSize: large ? 22 : 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Poppins',
      ),
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
  );

  Widget _chargeRow(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniLabelField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
          prefixText: '₹ ',
          prefixStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    ],
  );

  Widget _packagingSlabCard({
    required String range,
    required String rangeSubtitle,
    required String emoji,
    required TextEditingController ctrl,
    required String hint,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                range,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Text(
                rangeSubtitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: color.withOpacity(0.4),
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
              prefixText: '₹',
              prefixStyle: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pkgPreviewRow(String order, String fee) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          order,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            fee,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _previewPill(String km, String charge) => Column(
    children: [
      Text(
        km,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textMuted,
          fontFamily: 'Poppins',
        ),
      ),
      const SizedBox(height: 2),
      Text(
        charge,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    ],
  );

  Widget _timePicker({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(time),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap to change',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _infoBanner({
    required String icon,
    required String text,
    required Color color,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color == AppColors.textMuted
                  ? AppColors.textSecondary
                  : color,
              fontSize: 11,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoPoint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
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

  Widget _warningBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'app_settings table not found. SQL run karo pehle — Save button se auto-create hoga.',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sqlHelperCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.code_rounded, color: AppColors.primary, size: 14),
            SizedBox(width: 6),
            Text(
              'Supabase SQL — v2.0 + v3.0 All Columns',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            const sql =
                "ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_center_lat DOUBLE PRECISION DEFAULT 29.2183;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_center_lng DOUBLE PRECISION DEFAULT 79.5130;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_radius_km DOUBLE PRECISION DEFAULT 15.0;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_charge_5km_base DOUBLE PRECISION DEFAULT 70.0;\nALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_charge_per_km_after_5 DOUBLE PRECISION DEFAULT 10.0;";
            Clipboard.setData(const ClipboardData(text: sql));
            _snack('SQL copied! Supabase SQL editor mein paste karo ✅');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'ALTER TABLE app_settings ADD COLUMN... — tap to copy SQL',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _uploadPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.add_photo_alternate_outlined,
        color: AppColors.textMuted.withOpacity(0.5),
        size: 32,
      ),
      const SizedBox(height: 6),
      const Text(
        'Popup ke liye image upload karo',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Tap to select from gallery',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
    ],
  );

  Widget _slabDivider() =>
      Divider(color: AppColors.border.withOpacity(0.7), height: 1);
}
