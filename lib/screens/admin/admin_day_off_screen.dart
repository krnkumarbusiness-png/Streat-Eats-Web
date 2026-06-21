// lib/screens/admin/admin_day_off_screen.dart
// 2 features:
// 1. Aaj ke liye kisi bhi vendor ko temporarily off karo (day_off_date)
// 2. Mangalwar Special — har Tuesday non-veg vendors auto-hide
// Supabase: vendors.day_off_date (DATE column)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';

class AdminDayOffScreen extends StatefulWidget {
  const AdminDayOffScreen({super.key});

  @override
  State<AdminDayOffScreen> createState() => _AdminDayOffScreenState();
}

class _AdminDayOffScreenState extends State<AdminDayOffScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vendors = [];
  bool _loading = true;
  bool _savingTuesday = false;

  // Mangalwar (Tuesday) auto-off setting — app_settings table mein
  bool _tuesdayNonVegOff = false;

  final String _todayStr = DateTime.now().toIso8601String().substring(
    0,
    10,
  ); // "2026-05-20"

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadVendors(), _loadTuesdaySetting()]);
    setState(() => _loading = false);
  }

  Future<void> _loadVendors() async {
    try {
      final data = await _supabase
          .from('vendors')
          .select(
            'id, name, area, is_active, vendor_type, day_off_date, image_url, business_type',
          )
          .order('name');
      if (mounted) {
        setState(() => _vendors = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      _snack('Load failed: $e', isError: true);
    }
  }

  Future<void> _loadTuesdaySetting() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('tuesday_nonveg_off')
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _tuesdayNonVegOff = data?['tuesday_nonveg_off'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  // Aaj ke liye vendor off/on toggle
  Future<void> _toggleDayOff(String vendorId, bool isCurrentlyOff) async {
    try {
      await _supabase
          .from('vendors')
          .update({'day_off_date': isCurrentlyOff ? null : _todayStr})
          .eq('id', vendorId);
      await _loadVendors();
      _snack(
        isCurrentlyOff
            ? 'Vendor aaj ke liye wapas ON hua!'
            : 'Vendor aaj ke liye OFF kar diya!',
      );
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  // Mangalwar setting save karo
  Future<void> _saveTuesdaySetting(bool value) async {
    setState(() => _savingTuesday = true);
    try {
      // app_settings mein pehle row check karo
      final existing = await _supabase
          .from('app_settings')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('app_settings')
            .update({'tuesday_nonveg_off': value})
            .eq('id', existing['id']);
      } else {
        await _supabase.from('app_settings').insert({
          'tuesday_nonveg_off': value,
        });
      }

      setState(() {
        _tuesdayNonVegOff = value;
        _savingTuesday = false;
      });
      _snack(
        value
            ? 'Mangalwar Non-veg OFF mode ON kar diya! 🙏'
            : 'Mangalwar setting band kar di',
      );
    } catch (e) {
      setState(() => _savingTuesday = false);
      _snack('Failed: $e', isError: true);
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

  bool _isOffToday(Map<String, dynamic> vendor) {
    final dayOff = vendor['day_off_date'] as String?;
    return dayOff != null && dayOff == _todayStr;
  }

  String get _todayDayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  bool get _isTuesday => DateTime.now().weekday == 2;

  @override
  Widget build(BuildContext context) {
    final offTodayCount = _vendors.where((v) => _isOffToday(v)).length;
    final nonVegVendors = _vendors
        .where(
          (v) => v['vendor_type'] == 'non_veg' || v['vendor_type'] == 'both',
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Day Off & Special Days',
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
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Today info ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aaj: $_todayDayName',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '$offTodayCount vendors aaj ke liye off hain',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ══════════════════════════════════════════
                  // SECTION 1 — Mangalwar Special
                  // ══════════════════════════════════════════
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isTuesday
                            ? AppColors.primary.withOpacity(0.4)
                            : AppColors.border,
                        width: _isTuesday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.06),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7C3AED,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🙏',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mangalwar Special 🙏',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    Text(
                                      _isTuesday
                                          ? 'Aaj Mangalwar hai!'
                                          : 'Har Tuesday ke liye setting',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isTuesday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'TODAY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Toggle row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Non-Veg vendors Tuesday ko hide karo',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${nonVegVendors.length} non-veg/both vendors affected honge',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _savingTuesday
                                      ? const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => _saveTuesdaySetting(
                                            !_tuesdayNonVegOff,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            width: 52,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: _tuesdayNonVegOff
                                                  ? const Color(0xFF7C3AED)
                                                  : AppColors.border,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Stack(
                                              children: [
                                                AnimatedPositioned(
                                                  duration: const Duration(
                                                    milliseconds: 250,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                  left: _tuesdayNonVegOff
                                                      ? 26
                                                      : 2,
                                                  top: 2,
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ],
                              ),

                              if (_tuesdayNonVegOff) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7C3AED,
                                      ).withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Text(
                                    '✅ Active — Har Mangalwar ko non-veg vendors automatically app se hide ho jaenge. Customers sirf veg vendors dekhenge.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7C3AED),
                                      fontFamily: 'Poppins',
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Non-veg vendors list preview
                                const Text(
                                  'Ye vendors Tuesday ko hidden honge:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...nonVegVendors.map(
                                  (v) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          '🍗',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${v['name']} · ${v['area']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            v['vendor_type'] == 'non_veg'
                                                ? 'Non-Veg'
                                                : 'Both',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Poppins',
                                            ),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ══════════════════════════════════════════
                  // SECTION 2 — Aaj ke liye vendor toggle
                  // ══════════════════════════════════════════
                  const Text(
                    'Aaj Ke Liye Vendor Off Karo 🔒',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sirf aaj ke liye — kal automatically wapas on ho jaega',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._vendors.map((vendor) {
                    final offToday = _isOffToday(vendor);
                    final isActive = vendor['is_active'] as bool? ?? false;
                    final vendorType =
                        vendor['vendor_type'] as String? ?? 'both';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: offToday
                              ? AppColors.error.withOpacity(0.4)
                              : AppColors.border,
                          width: offToday ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Vendor type icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: offToday
                                    ? AppColors.error.withOpacity(0.08)
                                    : AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  vendorType == 'non_veg'
                                      ? '🍗'
                                      : vendorType == 'veg'
                                      ? '🥦'
                                      : '🍽️',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          vendor['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            fontFamily: 'Poppins',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!isActive)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.textMuted
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Permanently Off',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: AppColors.textMuted,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        vendor['area'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      if (offToday) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            '🔒 Aaj off hai',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: AppColors.error,
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

                            // Toggle button
                            GestureDetector(
                              onTap: () =>
                                  _toggleDayOff(vendor['id'], offToday),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: offToday
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: offToday
                                        ? AppColors.success.withOpacity(0.4)
                                        : AppColors.error.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  offToday ? 'ON karo' : 'OFF karo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: offToday
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
