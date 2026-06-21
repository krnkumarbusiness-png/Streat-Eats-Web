import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';

class PickedLocationResult {
  final double lat;
  final double lng;
  final String address;
  PickedLocationResult({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _pickedPosition = const LatLng(29.2183, 79.5130); // Haldwani default
  String _address = 'Move the map to select location';
  bool _loadingAddress = false;

  static const _primaryColor = Color(0xFFFF6B35);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _pickedPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_pickedPosition);
    } else {
      _detectCurrentLocation();
    }
  }

  Future<void> _detectCurrentLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos != null && mounted) {
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() => _pickedPosition = newPos);
        _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
        _reverseGeocode(newPos);
      } else {
        _reverseGeocode(_pickedPosition);
      }
    } catch (_) {
      _reverseGeocode(_pickedPosition);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.name,
          p.subLocality,
          p.locality,
        ].where((e) => e != null && e.trim().isNotEmpty).toList();
        if (!mounted) return;
        setState(() {
          _address = parts.isNotEmpty ? parts.join(', ') : 'Selected Location';
          _loadingAddress = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _address = 'Selected Location';
          _loadingAddress = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = 'Selected Location';
        _loadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedPosition,
              zoom: 16,
            ),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: (pos) => _pickedPosition = pos.target,
            onCameraIdle: () => _reverseGeocode(_pickedPosition),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Fixed center pin — map ko drag karke pin set karo (Swiggy/Zomato style)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_on_rounded,
                color: _primaryColor,
                size: 48,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Drag map to adjust pin',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _detectCurrentLocation,
              child: const Icon(
                Icons.my_location_rounded,
                color: _primaryColor,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DELIVERY LOCATION',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: _primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _loadingAddress
                              ? const Text(
                                  'Fetching address...',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: _textMuted,
                                  ),
                                )
                              : Text(
                                  _address,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loadingAddress
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  PickedLocationResult(
                                    lat: _pickedPosition.latitude,
                                    lng: _pickedPosition.longitude,
                                    address: _address,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
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
