import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import 'location_picker_screen.dart';
import 'add_address_details_screen.dart';

// ─── Colors ───────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFFFF8F0);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFFF1EB);
  static const primaryBorder = Color(0xFFFFD4BC);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF3D3D3D);
  static const textMuted = Color(0xFF6B7280);
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const error = Color(0xFFDC2626);
  static const border = Color(0xFFE5E7EB);
}

// ─── Saved Address Model ──────────────────────────────────
class _SavedAddress {
  final String id;
  final String label;
  final String address;
  final String landmark;
  final double? lat;
  final double? lng;
  final bool isDefault;

  _SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.landmark,
    required this.lat,
    required this.lng,
    required this.isDefault,
  });

  factory _SavedAddress.fromMap(Map<String, dynamic> m) => _SavedAddress(
    id: m['id'] as String,
    label: m['label'] as String? ?? 'Home',
    address: m['address'] as String? ?? '',
    landmark: m['landmark'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    isDefault: m['is_default'] as bool? ?? false,
  );

  IconData get icon {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  String get fullAddress =>
      landmark.isNotEmpty ? '$address, $landmark' : address;
}

// ═══════════════════════════════════════════════════════════
class AddressSelectionScreen extends StatefulWidget {
  final double? currentLat;
  final double? currentLng;
  const AddressSelectionScreen({super.key, this.currentLat, this.currentLng});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<_SavedAddress> _savedAddresses = [];
  bool _loadingSaved = true;
  bool _detectingCurrent = false;
  bool _searching = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load all saved addresses ───────────────────────────
  Future<void> _loadSavedAddresses() async {
    setState(() => _loadingSaved = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loadingSaved = false);
        return;
      }
      final data = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _savedAddresses = (data as List)
              .map((e) => _SavedAddress.fromMap(e))
              .toList();
          _loadingSaved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? _C.error : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Use current GPS location ───────────────────────────
  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _detectingCurrent = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) {
        _snack('Location detect nahi ho saka. Permission check karo.');
        return;
      }
      if (!mounted) return;
      final result = await Navigator.push<PickedLocationResult>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialLat: pos.latitude,
            initialLng: pos.longitude,
          ),
        ),
      );
      if (result != null && mounted) {
        await _askLabelAndSave(result);
      }
    } catch (_) {
      _snack('Kuch gadbad ho gayi. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _detectingCurrent = false);
    }
  }

  // ── Add new via map ────────────────────────────────────
  Future<void> _addNewAddress() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      await _askLabelAndSave(result);
    }
  }

  // ── Label picker then save ─────────────────────────────
  Future<void> _askLabelAndSave(PickedLocationResult result) async {
    await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressDetailsScreen(
          pickedLocation: result,
          isFirstAddress: _savedAddresses.isEmpty,
        ),
      ),
    );
    // Reload saved addresses after returning
    await _loadSavedAddresses();
  }

  Future<void> _saveAddress(PickedLocationResult result, String label) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) Navigator.pop(context, result);
        return;
      }
      final isFirst = _savedAddresses.isEmpty;
      await _supabase.from('delivery_addresses').insert({
        'user_id': userId,
        'label': label,
        'address': result.address,
        'landmark': '',
        'lat': result.lat,
        'lng': result.lng,
        'is_default': isFirst,
      });
      // Legacy users table update
      await _supabase
          .from('users')
          .update({
            'delivery_address': result.address,
            'last_lat': result.lat,
            'last_lng': result.lng,
          })
          .eq('id', userId);

      _snack('Address save ho gaya! ✅', isError: false);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) Navigator.pop(context, result);
    }
  }

  // ── Delete address ─────────────────────────────────────
  Future<void> _deleteAddress(String id) async {
    HapticFeedback.lightImpact();
    setState(() => _deletingId = id);
    try {
      await _supabase.from('delivery_addresses').delete().eq('id', id);
      await _loadSavedAddresses();
      _snack('Address delete ho gaya', isError: false);
    } catch (_) {
      _snack('Delete nahi ho saka. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  // ── Select saved address and return ───────────────────
  void _selectAddress(_SavedAddress addr) {
    if (addr.lat == null || addr.lng == null) return;
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      PickedLocationResult(
        lat: addr.lat!,
        lng: addr.lng!,
        address: addr.fullAddress,
      ),
    );
  }

  bool _isCurrentlySelected(_SavedAddress addr) {
    if (addr.lat == null || addr.lng == null) return false;
    if (widget.currentLat == null || widget.currentLng == null) return false;
    return (widget.currentLat! - addr.lat!).abs() < 0.0005 &&
        (widget.currentLng! - addr.lng!).abs() < 0.0005;
  }

  // ── Search by name ─────────────────────────────────────
  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _searching = true);
    try {
      final locations = await locationFromAddress(
        '$query, Haldwani, Uttarakhand',
      );
      if (locations.isEmpty) {
        _snack('Location nahi mili. Alag naam try karo.');
        return;
      }
      final loc = locations.first;
      if (!mounted) return;
      final result = await Navigator.push<PickedLocationResult>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialLat: loc.latitude,
            initialLng: loc.longitude,
          ),
        ),
      );
      if (result != null && mounted) {
        await _askLabelAndSave(result);
      }
    } catch (_) {
      _snack('Location nahi mili. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                color: _C.primary,
                onRefresh: _loadSavedAddresses,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section label ──
                      const Text(
                        'QUICK OPTIONS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: _C.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Use Current Location card ──
                      _buildOptionCard(
                        icon: Icons.my_location_rounded,
                        iconBg: _C.primaryLight,
                        iconBorder: _C.primaryBorder,
                        iconColor: _C.primary,
                        title: 'Use my current location',
                        subtitle: 'Auto detect where you are right now',
                        isLoading: _detectingCurrent,
                        onTap: _detectingCurrent ? null : _useCurrentLocation,
                      ),

                      const SizedBox(height: 10),

                      // ── Add New Address card ──
                      _buildOptionCard(
                        icon: Icons.add_location_alt_rounded,
                        iconBg: _C.primaryLight,
                        iconBorder: _C.primaryBorder,
                        iconColor: _C.primary,
                        title: 'Add New Address',
                        subtitle: 'Pick on map & save for later',
                        isLoading: false,
                        onTap: _addNewAddress,
                        showArrow: true,
                      ),

                      const SizedBox(height: 24),

                      // ── Saved Addresses ──
                      if (_loadingSaved)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(
                              color: _C.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            const Text(
                              'SAVED ADDRESSES',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: _C.textMuted,
                              ),
                            ),
                            const Spacer(),
                            if (_savedAddresses.isNotEmpty)
                              Text(
                                '${_savedAddresses.length} saved',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: _C.textMuted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_savedAddresses.isEmpty)
                          _buildEmptyAddresses()
                        else
                          ..._savedAddresses.map(
                            (addr) => _buildSavedAddressCard(addr),
                          ),
                      ],

                      const SizedBox(height: 16),
                      // Tip row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add Home, Work, and other spots for quicker orders next time.',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: _C.textMuted,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'My Addresses',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchAddress(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: _C.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search area, street, landmark...',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _C.textMuted,
          ),
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: _C.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded, color: _C.textMuted, size: 20),
          suffixIcon: GestureDetector(
            onTap: _searchAddress,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Search',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          filled: true,
          fillColor: _C.bg,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Generic Option Card (current loc / add new) ───────
  Widget _buildOptionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconBorder,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: iconBorder),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: _C.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _C.textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Saved Address Card ────────────────────────────────
  Widget _buildSavedAddressCard(_SavedAddress addr) {
    final isSelected = _isCurrentlySelected(addr);
    final isDeleting = _deletingId == addr.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _C.primary : _C.border,
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top: icon + label + address + actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _C.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _C.primaryBorder),
                  ),
                  child: Icon(addr.icon, color: _C.primary, size: 22),
                ),
                const SizedBox(width: 12),

                // Label + address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            addr.label,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _C.textPrimary,
                            ),
                          ),
                          if (addr.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _C.border,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _C.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addr.fullAddress,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _C.textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Delete icon
                GestureDetector(
                  onTap: isDeleting ? null : () => _confirmDelete(addr),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: _C.error,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          color: _C.error,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),

          // ── Bottom: Select Address button ──
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                // Select button
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectAddress(addr),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _C.primaryLight
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.check_rounded,
                            color: _C.primary,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSelected ? 'Selected ✓' : 'Select Address',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Divider
                Container(width: 1, height: 42, color: _C.border),

                // Navigate icon
                GestureDetector(
                  onTap: () => _selectAddress(addr),
                  child: Container(
                    width: 56,
                    height: 44,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: _C.textMuted,
                      size: 18,
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

  // ── Delete Confirm Dialog ──────────────────────────────
  Future<void> _confirmDelete(_SavedAddress addr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Address?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        content: Text(
          '"${addr.label}" address delete ho jaayega.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _C.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _C.textMuted,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: _C.error,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) await _deleteAddress(addr.id);
  }

  // ── Empty State ───────────────────────────────────────
  Widget _buildEmptyAddresses() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: const Column(
        children: [
          Text('📍', style: TextStyle(fontSize: 36)),
          SizedBox(height: 12),
          Text(
            'No saved addresses yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add Home, Work, or any location\nfor quicker orders!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _C.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Label Picker Bottom Sheet
// ═══════════════════════════════════════════════════════════
class _LabelPickerSheet extends StatelessWidget {
  const _LabelPickerSheet();

  @override
  Widget build(BuildContext context) {
    final labels = [
      {'label': 'Home', 'emoji': '🏠'},
      {'label': 'Work', 'emoji': '💼'},
      {'label': 'Other', 'emoji': '📍'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Save address as',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a label for quick access',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          ...labels.map(
            (l) => GestureDetector(
              onTap: () => Navigator.pop(context, l['label']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Text(l['emoji']!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Text(
                      l['label']!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF6B7280),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
