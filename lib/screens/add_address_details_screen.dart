import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_picker_screen.dart';

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
  static const error = Color(0xFFDC2626);
  static const border = Color(0xFFE5E7EB);
}

// ─── Result Model ─────────────────────────────────────────
class AddressDetailsResult {
  final String label;
  final String flatNo;
  final String landmark;
  final String receiverName;
  final String receiverPhone;

  AddressDetailsResult({
    required this.label,
    required this.flatNo,
    required this.landmark,
    required this.receiverName,
    required this.receiverPhone,
  });
}

// ═══════════════════════════════════════════════════════════
class AddAddressDetailsScreen extends StatefulWidget {
  final PickedLocationResult pickedLocation;
  final bool isFirstAddress; // for is_default flag

  const AddAddressDetailsScreen({
    super.key,
    required this.pickedLocation,
    required this.isFirstAddress,
  });

  @override
  State<AddAddressDetailsScreen> createState() =>
      _AddAddressDetailsScreenState();
}

class _AddAddressDetailsScreenState extends State<AddAddressDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final _flatController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedLabel = 'Home';
  bool _saving = false;

  final _labels = [
    {'label': 'Home', 'icon': Icons.home_rounded},
    {'label': 'Work', 'icon': Icons.work_rounded},
    {'label': 'Other', 'icon': Icons.location_on_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  @override
  void dispose() {
    _flatController.dispose();
    _landmarkController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _prefillUserData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('users')
          .select('name, phone')
          .eq('id', userId)
          .single();
      if (mounted) {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      }
    } catch (_) {}
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

  Future<void> _saveAddress() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _snack('Receiver ka naam daalo');
      return;
    }
    if (phone.isEmpty) {
      _snack('Phone number daalo');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final flatNo = _flatController.text.trim();
      final landmark = _landmarkController.text.trim();

      // Full address string
      final fullAddress = [
        if (flatNo.isNotEmpty) flatNo,
        widget.pickedLocation.address,
      ].join(', ');

      await _supabase.from('delivery_addresses').insert({
        'user_id': userId,
        'label': _selectedLabel,
        'address': fullAddress,
        'landmark': landmark,
        'lat': widget.pickedLocation.lat,
        'lng': widget.pickedLocation.lng,
        'is_default': widget.isFirstAddress,
        'receiver_name': name,
        'receiver_phone': phone,
      });

      // Legacy users table update
      await _supabase
          .from('users')
          .update({
            'delivery_address': fullAddress,
            'last_lat': widget.pickedLocation.lat,
            'last_lng': widget.pickedLocation.lng,
          })
          .eq('id', userId);

      _snack('Address save ho gaya! ✅', isError: false);

      if (mounted) {
        // Return enriched result back to AddressSelectionScreen
        Navigator.pop(
          context,
          PickedLocationResult(
            lat: widget.pickedLocation.lat,
            lng: widget.pickedLocation.lng,
            address: fullAddress,
          ),
        );
      }
    } catch (e) {
      _snack('Save nahi ho saka. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Change location — wapas LocationPickerScreen pe ──
  Future<void> _changeLocation() async {
    final result = await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: widget.pickedLocation.lat,
          initialLng: widget.pickedLocation.lng,
        ),
      ),
    );
    if (result != null && mounted) {
      // Naya result ke saath wapas AddressSelectionScreen pe jaao
      Navigator.pop(context, result);
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Save As ──
                    _sectionLabel('Save as'),
                    const SizedBox(height: 10),
                    _buildLabelChips(),

                    const SizedBox(height: 20),

                    // ── Flat / House No ──
                    _sectionLabel('Flat / House No / Floor'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _flatController,
                      hint: 'e.g. A-402, 4th Floor',
                      icon: Icons.home_work_rounded,
                    ),

                    const SizedBox(height: 16),

                    // ── Landmark ──
                    _sectionLabel('Nearby Landmark (Optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _landmarkController,
                      hint: 'e.g. Near City Park',
                      icon: Icons.flag_rounded,
                    ),

                    const SizedBox(height: 16),

                    // ── Receiver Name ──
                    _sectionLabel("Receiver's Name"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Full name',
                      icon: Icons.person_rounded,
                      keyboardType: TextInputType.name,
                    ),

                    const SizedBox(height: 16),

                    // ── Receiver Phone ──
                    _sectionLabel("Receiver's Phone"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _phoneController,
                      hint: '10-digit mobile number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── Bottom: Selected Location + Save Button ──
            _buildBottomBar(),
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
            'Add Address Details',
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

  // ── Section Label ─────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _C.textPrimary,
      ),
    );
  }

  // ── Label Chips (Home / Work / Other) ─────────────────
  Widget _buildLabelChips() {
    return Row(
      children: _labels.map((l) {
        final isSelected = _selectedLabel == l['label'];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedLabel = l['label'] as String);
            },
            child: Container(
              margin: EdgeInsets.only(right: l['label'] != 'Other' ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? _C.primaryLight : _C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? _C.primary : _C.border,
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    l['icon'] as IconData,
                    color: isSelected ? _C.primary : _C.textMuted,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _C.primary : _C.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Text Field ────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: _C.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: _C.textMuted,
        ),
        prefixIcon: Icon(icon, color: _C.textMuted, size: 20),
        counterText: '', // maxLength counter hide karo
        filled: true,
        fillColor: _C.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
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
    );
  }

  // ── Bottom Bar ────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected Location row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: _C.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECTED LOCATION',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: _C.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.pickedLocation.address,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _changeLocation,
                  child: const Text(
                    'CHANGE',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _C.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Save Address button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                disabledBackgroundColor: _C.primaryBorder,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save Address',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
