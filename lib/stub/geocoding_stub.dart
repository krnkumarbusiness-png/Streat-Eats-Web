// Stubs for geocoding package — compiled on web where geocoding is unavailable.
// All calls are guarded with kIsWeb at runtime so these stubs are never invoked.

class Placemark {
  final String? name;
  final String? street;
  final String? subLocality;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;

  const Placemark({
    this.name,
    this.street,
    this.subLocality,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
  });
}

class Location {
  final double latitude;
  final double longitude;
  const Location({required this.latitude, required this.longitude});
}

Future<List<Placemark>> placemarkFromCoordinates(
  double latitude,
  double longitude, {
  String? localeIdentifier,
}) async =>
    [];

Future<List<Location>> locationFromAddress(
  String address, {
  String? localeIdentifier,
}) async =>
    [];
