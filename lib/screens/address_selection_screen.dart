import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import 'location_picker_screen.dart';

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

  bool _loadingSaved = true;
  bool _detectingCurrent = false;
  bool _searching = false;

  bool _hasSavedAddress = false;
  String _savedAddressText = '';
  String _savedLandmark = '';
  double? _savedLat;
  double? _savedLng;

  static const _bgColor = Color(0xFFFFF8F0);
  static const _surfaceColor = Color(0xFFFFFFFF);
  static const _primaryColor = Color(0xFFFF6B35);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF3D3D3D);
  static const _textMuted = Color(0xFF6B7280);
  static const _successColor = Color(0xFF16A34A);
  static const _errorColor = Color(0xFFDC2626);
  static const _borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loadingSaved = false);
        return;
      }
      final data = await _supabase
          .from('users')
          .select('delivery_address, delivery_landmark, last_lat, last_lng')
          .eq('id', userId)
          .maybeSingle();
      final addr = (data?['delivery_address'] as String?)?.trim() ?? '';
      if (addr.isNotEmpty) {
        setState(() {
          _savedAddressText = addr;
          _savedLandmark =
              (data?['delivery_landmark'] as String?)?.trim() ?? '';
          _savedLat = (data?['last_lat'] as num?)?.toDouble();
          _savedLng = (data?['last_lng'] as num?)?.toDouble();
          _hasSavedAddress = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  bool get _isSavedCurrentlySelected {
    if (!_hasSavedAddress || _savedLat == null || _savedLng == null) {
      return false;
    }
    if (widget.currentLat == null || widget.currentLng == null) return false;
    final diffLat = (widget.currentLat! - _savedLat!).abs();
    final diffLng = (widget.currentLng! - _savedLng!).abs();
    return diffLat < 0.0005 && diffLng < 0.0005;
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _detectingCurrent = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) {
        _snack(
          'Could not detect your location. Please check location permission.',
        );
        return;
      }
      if (!mounted) return;
      // ✅ Raw GPS seedha accept nahi karna — map pe le jao taaki
      // user pin ko confirm/adjust kar sake (precision ke liye)
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
        await _saveAndReturn(result);
      }
    } catch (_) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _detectingCurrent = false);
    }
  }

  // REPLACE:
  Future<void> _addNewAddress() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      await _saveAndReturn(result);
    }
  }

  Future<void> _saveAndReturn(PickedLocationResult result) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('users')
            .update({
              'delivery_address': result.address,
              'delivery_landmark': '',
              'last_lat': result.lat,
              'last_lng': result.lng,
            })
            .eq('id', userId);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context, result);
  }

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
        _snack('Location not found. Try a different search.');
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
      // REPLACE:
      if (result != null && mounted) {
        await _saveAndReturn(result);
      }
    } catch (_) {
      _snack('Could not find this location. Try searching differently.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSavedAddress() {
    if (_savedLat == null || _savedLng == null) return;
    HapticFeedback.lightImpact();
    final fullAddress = _savedLandmark.isNotEmpty
        ? '$_savedAddressText, $_savedLandmark'
        : _savedAddressText;
    Navigator.pop(
      context,
      PickedLocationResult(
        lat: _savedLat!,
        lng: _savedLng!,
        address: fullAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActionsCard(),
                    const SizedBox(height: 24),
                    if (_loadingSaved)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_hasSavedAddress) ...[
                      const Text(
                        'SAVED ADDRESSES',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSavedAddressCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: _surfaceColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _textPrimary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Enter your Address',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      color: _surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchAddress(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: _textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search for area, street name...',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: _textMuted,
          ),
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded, color: _textMuted, size: 22),
          filled: true,
          fillColor: _bgColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionRow(
            icon: Icons.my_location_rounded,
            label: 'Use my current location',
            onTap: _useCurrentLocation,
            isLoading: _detectingCurrent,
          ),
          const Divider(
            height: 1,
            color: _borderColor,
            indent: 16,
            endIndent: 16,
          ),
          _buildActionRow(
            icon: Icons.add_rounded,
            label: 'Add New Address',
            onTap: _addNewAddress,
            isLoading: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon, color: _primaryColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressCard() {
    final isSelected = _isSavedCurrentlySelected;
    return GestureDetector(
      onTap: _selectSavedAddress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor.withOpacity(0.4) : _borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_rounded, color: _primaryColor, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Home',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CURRENTLY SELECTED',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _savedLandmark.isNotEmpty
                  ? '$_savedAddressText, $_savedLandmark'
                  : _savedAddressText,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
