// lib/screens/admin/admin_offers_screen.dart
// v3.0 — Affiliate Tracking + Min Order Value added
// ✅ NEW: affiliate_name, commission_per_order, min_order_value fields in form
// ✅ NEW: Affiliate info chip shown on offer card
// ✅ All existing features preserved (per_user_limit, discount types, notifications, etc.)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('offers')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _toggleOffer(String offerId, bool currentActive) async {
    try {
      await _supabase
          .from('offers')
          .update({'is_active': !currentActive})
          .eq('id', offerId);
      await _loadOffers();
      _snack(!currentActive ? 'Offer activated ✅' : 'Offer deactivated');
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _deleteOffer(String offerId, String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Offer?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Offer "$code" delete ho jayega. Undo nahi hoga.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
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
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase.from('offers').delete().eq('id', offerId);
      await _loadOffers();
      _snack('Offer deleted');
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _sendOfferNotification(Map<String, dynamic> offer) async {
    try {
      final code = offer['code'] as String;
      final discountType = offer['discount_type'] as String? ?? 'flat';
      final discountValue = offer['discount_value'] as int? ?? 0;
      final discountText = discountType == 'flat'
          ? '₹$discountValue off'
          : '$discountValue% off';
      final description = offer['description'] as String? ?? '';

      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'send_to_all': true,
          'title': '🎉 Special Offer! Use code $code',
          'body': description.isNotEmpty
              ? '$description — $discountText'
              : 'Get $discountText on your next order! Use code: $code',
          'data': {'type': 'offer', 'offer_code': code},
        },
      );

      await _supabase
          .from('offers')
          .update({'notification_sent': true})
          .eq('id', offer['id']);

      await _loadOffers();
      _snack('Offer notification sab users ko bhej di! ✅');
    } catch (e) {
      _snack('Notification failed: $e', isError: true);
    }
  }

  void _showCreateEditSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OfferFormSheet(
        existing: existing,
        onSaved: () {
          Navigator.pop(context);
          _loadOffers();
          _snack(existing == null ? 'Offer created! ✅' : 'Offer updated ✅');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Offers & Promo Codes', style: AppStyles.screenTitle),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            onPressed: _loadOffers,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEditSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Offer',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 13,
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
          : _offers.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadOffers,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildOfferCard(_offers[i]),
              ),
            ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final code = offer['code'] as String;
    final isActive = offer['is_active'] as bool? ?? false;
    final discountType = offer['discount_type'] as String? ?? 'flat';
    final discountValue = offer['discount_value'] as int? ?? 0;
    final maxUses = offer['max_uses'] as int? ?? 0;
    final usedCount = offer['used_count'] as int? ?? 0;
    final perUserLimit = offer['per_user_limit'] as int? ?? 1;
    final description = offer['description'] as String? ?? '';
    final notifSent = offer['notification_sent'] as bool? ?? false;
    final minOrder = offer['min_order_amount'] as int? ?? 0;
    final expiresAt = offer['expires_at'] as String?;

    // ✅ NEW — Affiliate fields
    final affiliateName = offer['affiliate_name'] as String?;
    final commissionPerOrder =
        (offer['commission_per_order'] as num?)?.toDouble() ?? 0;
    final minOrderValue = (offer['min_order_value'] as num?)?.toDouble() ?? 0;
    final hasAffiliate = affiliateName != null && affiliateName.isNotEmpty;

    final discountText = discountType == 'flat'
        ? '₹$discountValue off'
        : '$discountValue% off';
    final usagePercent = maxUses > 0
        ? (usedCount / maxUses).clamp(0.0, 1.0)
        : 0.0;
    final isFull = maxUses > 0 && usedCount >= maxUses;

    final statusColor = isFull
        ? AppColors.error
        : isActive
        ? AppColors.success
        : AppColors.textMuted;
    final statusText = isFull
        ? 'Limit Reached'
        : isActive
        ? 'Active'
        : 'Inactive';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive && !isFull
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.border,
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
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isActive && !isFull)
                  ? AppColors.primary.withOpacity(0.05)
                  : AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
                        statusText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discountText,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(description, style: AppStyles.bodyText),
                  const SizedBox(height: 10),
                ],

                // ✅ NEW — Affiliate info banner
                if (hasAffiliate) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_pin_rounded,
                          color: Color(0xFF7C3AED),
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Affiliate: ',
                                  style: TextStyle(color: Color(0xFF7C3AED)),
                                ),
                                TextSpan(
                                  text: affiliateName,
                                  style: const TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (commissionPerOrder > 0)
                                  TextSpan(
                                    text:
                                        '  •  ₹${commissionPerOrder.toStringAsFixed(0)}/order commission',
                                    style: TextStyle(
                                      color: const Color(
                                        0xFF7C3AED,
                                      ).withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Detail chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (minOrder > 0)
                      _chip(
                        Icons.shopping_cart_outlined,
                        'Min ₹$minOrder',
                        AppColors.warning,
                      ),
                    // ✅ NEW — min_order_value chip (affiliate min order)
                    if (minOrderValue > 0 && minOrderValue != minOrder)
                      _chip(
                        Icons.local_offer_outlined,
                        'Code Min ₹${minOrderValue.toStringAsFixed(0)}',
                        const Color(0xFF7C3AED),
                      ),
                    _chip(
                      Icons.group_outlined,
                      '$usedCount/$maxUses used',
                      isFull ? AppColors.error : AppColors.primary,
                    ),
                    _chip(
                      Icons.person_outlined,
                      'Max $perUserLimit/user',
                      AppColors.revenue,
                    ),
                    if (expiresAt != null)
                      _chip(
                        Icons.timer_outlined,
                        'Expires ${_formatDate(expiresAt)}',
                        AppColors.textMuted,
                      ),
                    if (notifSent)
                      _chip(
                        Icons.notifications_active_rounded,
                        'Notified',
                        AppColors.success,
                      ),
                  ],
                ),

                // Usage progress
                if (maxUses > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Usage: $usedCount / $maxUses',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${(usagePercent * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFull ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: usagePercent,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isFull ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (!notifSent && isActive && !isFull)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendOfferNotification(offer),
                      icon: const Icon(Icons.notifications_rounded, size: 14),
                      label: const Text(
                        'Notify All',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (!notifSent && isActive && !isFull) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _toggleOffer(offer['id'] as String, isActive),
                    icon: Icon(
                      isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 14,
                    ),
                    label: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive
                          ? AppColors.warning
                          : AppColors.success,
                      side: BorderSide(
                        color: isActive
                            ? AppColors.warning.withOpacity(0.4)
                            : AppColors.success.withOpacity(0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showCreateEditSheet(existing: offer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.edit_outlined, size: 16),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deleteOffer(offer['id'] as String, code),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
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
                Icons.local_offer_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text('No Offers Yet', style: AppStyles.sectionHeader),
            const SizedBox(height: 8),
            const Text(
              'Create your first offer code\nto attract more customers!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreateEditSheet(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Create Offer',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Offer Form Bottom Sheet — v3.0
// ✅ NEW: affiliate_name, commission_per_order, min_order_value
// ✅ All existing: code, desc, discount, max_uses, min_order_amount,
//    per_user_limit, expiry, active toggle
// ══════════════════════════════════════════════════════════════

class _OfferFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _OfferFormSheet({this.existing, required this.onSaved});

  @override
  State<_OfferFormSheet> createState() => _OfferFormSheetState();
}

class _OfferFormSheetState extends State<_OfferFormSheet> {
  final _supabase = Supabase.instance.client;

  // Existing controllers
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _discountController = TextEditingController();
  final _maxUsesController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _perUserLimitController = TextEditingController();

  // ✅ NEW controllers
  final _affiliateNameController = TextEditingController();
  final _commissionController = TextEditingController();
  final _minOrderValueController = TextEditingController();

  String _discountType = 'flat';
  bool _isActive = true;
  bool _isSaving = false;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _codeController.text = e['code'] as String? ?? '';
      _descController.text = e['description'] as String? ?? '';
      _discountController.text =
          (e['discount_value'] as int?)?.toString() ?? '';
      _maxUsesController.text = (e['max_uses'] as int?)?.toString() ?? '100';
      _minOrderController.text =
          (e['min_order_amount'] as int?)?.toString() ?? '0';
      _perUserLimitController.text =
          (e['per_user_limit'] as int?)?.toString() ?? '1';
      // ✅ NEW — load existing affiliate data
      _affiliateNameController.text = e['affiliate_name'] as String? ?? '';
      _commissionController.text =
          (e['commission_per_order'] as num?)?.toString() ?? '';
      _minOrderValueController.text =
          (e['min_order_value'] as num?)?.toString() ?? '0';
      _discountType = e['discount_type'] as String? ?? 'flat';
      _isActive = e['is_active'] as bool? ?? true;
      final exp = e['expires_at'] as String?;
      if (exp != null) _expiresAt = DateTime.tryParse(exp);
    } else {
      _maxUsesController.text = '100';
      _minOrderController.text = '0';
      _perUserLimitController.text = '1';
      _minOrderValueController.text = '0';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _discountController.dispose();
    _maxUsesController.dispose();
    _minOrderController.dispose();
    _perUserLimitController.dispose();
    _affiliateNameController.dispose();
    _commissionController.dispose();
    _minOrderValueController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    final code = _codeController.text.trim().toUpperCase();
    final discountStr = _discountController.text.trim();

    if (code.isEmpty || discountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Code aur discount required hai',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final affiliateName = _affiliateNameController.text.trim();
      final commission =
          double.tryParse(_commissionController.text.trim()) ?? 0;
      final minOrderVal =
          double.tryParse(_minOrderValueController.text.trim()) ?? 0;

      final data = {
        'code': code,
        'description': _descController.text.trim(),
        'discount_type': _discountType,
        'discount_value': int.tryParse(discountStr) ?? 0,
        'max_uses': int.tryParse(_maxUsesController.text.trim()) ?? 100,
        'min_order_amount': int.tryParse(_minOrderController.text.trim()) ?? 0,
        'per_user_limit':
            int.tryParse(_perUserLimitController.text.trim()) ?? 1,
        'is_active': _isActive,
        'expires_at': _expiresAt?.toIso8601String(),
        // ✅ NEW — affiliate fields
        'affiliate_name': affiliateName.isEmpty ? null : affiliateName,
        'commission_per_order': commission > 0 ? commission : null,
        'min_order_value': minOrderVal,
      };

      if (widget.existing != null) {
        await _supabase
            .from('offers')
            .update(data)
            .eq('id', widget.existing!['id']);
      } else {
        await _supabase.from('offers').insert(data);
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit Offer' : 'Create New Offer',
              style: AppStyles.sectionHeader,
            ),
            const SizedBox(height: 20),

            // ── Code ────────────────────────────────────────────
            _label('OFFER CODE *'),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 2,
                color: AppColors.textPrimary,
              ),
              decoration: _inputDecor(
                'e.g. SAVE20',
                Icons.local_offer_outlined,
              ),
            ),

            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────────
            _label('DESCRIPTION'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: _inputDecor(
                'e.g. Flat ₹20 off on all orders',
                Icons.description_outlined,
              ),
            ),

            const SizedBox(height: 16),

            // ── Discount ─────────────────────────────────────────
            _label('DISCOUNT *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _typeBtn('flat', '₹ Flat'),
                      _typeBtn('percent', '% Off'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _inputDecor(
                      _discountType == 'flat' ? 'e.g. 20' : 'e.g. 10',
                      _discountType == 'flat'
                          ? Icons.currency_rupee_rounded
                          : Icons.percent_rounded,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Max Uses + Min Order ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('MAX USES (TOTAL)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _maxUsesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: _inputDecor('100', Icons.group_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('MIN ORDER AMT (₹)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _minOrderController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: _inputDecor(
                          '0',
                          Icons.shopping_cart_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Per User Limit ────────────────────────────────────
            _label('MAX USES PER USER'),
            const SizedBox(height: 4),
            const Text(
              'Ek user kitni baar yeh code use kar sakta hai',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _perUserLimitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _inputDecor(
                      '1 (default)',
                      Icons.person_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    _limitBtn('1'),
                    const SizedBox(width: 6),
                    _limitBtn('2'),
                    const SizedBox(width: 6),
                    _limitBtn('∞', value: '999'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.revenue.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.revenue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.revenue,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1 = sirf ek baar | 2 = do baar | 999 = unlimited',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.revenue.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ NEW — Affiliate Details Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.person_pin_rounded,
                          color: Color(0xFF7C3AED),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AFFILIATE DETAILS',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Optional — sirf affiliate codes ke liye',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Affiliate Name
                  const Text(
                    'AFFILIATE NAME',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _affiliateNameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _inputDecorColored(
                      'e.g. Rashi Bisht',
                      Icons.person_outline_rounded,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Commission + Min Order Value side by side
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'COMMISSION/ORDER (₹)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _commissionController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: _inputDecorColored(
                                'e.g. 10',
                                Icons.currency_rupee_rounded,
                                const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MIN ORDER VALUE (₹)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _minOrderValueController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: _inputDecorColored(
                                '0 (no limit)',
                                Icons.shopping_bag_outlined,
                                const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
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
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Min Order Value = coupon apply hone ke liye minimum cart amount. Commission = har use pe affiliate ko milega (Affiliate Ledger mein track hoga).',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF7C3AED),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Expiry Date ───────────────────────────────────────
            _label('EXPIRY DATE (OPTIONAL)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickExpiry,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _expiresAt != null
                          ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                          : 'No expiry (optional)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: _expiresAt != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (_expiresAt != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiresAt = null),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Active Toggle ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.toggle_on_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Active (visible to users)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Save Button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? 'Update Offer' : 'Create Offer',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitBtn(String label, {String? value}) {
    final val = value ?? label;
    final isSelected = _perUserLimitController.text == val;
    return GestureDetector(
      onTap: () => setState(() => _perUserLimitController.text = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String value, String label) {
    final isSelected = _discountType == value;
    return GestureDetector(
      onTap: () => setState(() => _discountType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.8,
    ),
  );

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 13,
      fontFamily: 'Poppins',
    ),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
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
    contentPadding: const EdgeInsets.all(14),
  );

  // ✅ NEW — colored border variant for affiliate section
  InputDecoration _inputDecorColored(String hint, IconData icon, Color color) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: color.withOpacity(0.6), size: 18),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      );
}
