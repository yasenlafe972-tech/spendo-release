import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  /// Requests permissions and retrieves the current GPS coordinates.
  Future<LocationResult?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return null;
      }

      // Fast accurate position with 10s timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Opens the coordinates directly in Google Maps or external map app.
  static Future<bool> openMap(double latitude, double longitude) async {
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

    try {
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(googleMapsUrl,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
    return false;
  }
}
