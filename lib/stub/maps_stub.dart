// Stubs for google_maps_flutter — compiled on web where Google Maps is unavailable.
// These allow the code to compile; map features are disabled on web via kIsWeb guards.

import 'package:flutter/material.dart';

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class CameraPosition {
  final LatLng target;
  final double zoom;
  const CameraPosition({required this.target, this.zoom = 12.0});
}

class CameraUpdate {
  const CameraUpdate._();
  static CameraUpdate newLatLng(LatLng latLng) => const CameraUpdate._();
  static CameraUpdate newLatLngZoom(LatLng latLng, double zoom) =>
      const CameraUpdate._();
  static CameraUpdate newCameraPosition(CameraPosition position) =>
      const CameraUpdate._();
}

class GoogleMapController {
  Future<void> animateCamera(CameraUpdate update) async {}
  void dispose() {}
}

typedef MapCreatedCallback = void Function(GoogleMapController);
typedef CameraPositionCallback = void Function(CameraPosition);

class GoogleMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final MapCreatedCallback? onMapCreated;
  final CameraPositionCallback? onCameraMove;
  final VoidCallback? onCameraIdle;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;

  const GoogleMap({
    super.key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = true,
    this.zoomControlsEnabled = true,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
