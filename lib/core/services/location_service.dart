import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

  static const Map<String, (double, double)> _knownTowns = {
    'طمرة': (32.8530, 35.1970),
    'كابول': (32.8680, 35.2100),
    'سخنين': (32.8660, 35.3000),
    'عرابة': (32.8550, 35.3380),
    'مجد الكروم': (32.9190, 35.2570),
    'البعنة': (32.9260, 35.2650),
    'دير الأسد': (32.9300, 35.2700),
    'شفاعمرو': (32.8050, 35.1700),
    'كفر مندا': (32.8120, 35.2600),
    'الناصرة': (32.7000, 35.3000),
    'كفر كنا': (32.7470, 35.3380),
    'الرينة': (32.7230, 35.3180),
    'عكا': (32.9280, 35.0820),
    'حيفا': (32.7940, 34.9896),
    'كريات بيالك': (32.8333, 35.0833),
    'كرمئيل': (32.9130, 35.2960),
    'يركا': (32.9550, 35.1950),
    'أبو سنان': (32.9580, 35.1700),
    'كفر ياسيف': (32.9530, 35.1630),
    'المغار': (32.8900, 35.4050),
    'دبورية': (32.6950, 35.3700),
  };

  /// Requests permissions, retrieves current GPS coordinates, and resolves a readable address.
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

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return null;

      final resolvedAddress = await reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        address: resolvedAddress,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Resolves latitude/longitude into a readable city/street name with offline town fallback.
  Future<String> reverseGeocode(double lat, double lon) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&accept-language=ar,he',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'SpendoFinanceApp/1.0');
      final res = await req.close().timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final city = addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              addr['suburb'];
          final road = addr['road'] ?? addr['neighbourhood'];
          if (city != null && road != null && city.toString() != road.toString()) {
            return '$city - $road';
          }
          if (city != null) {
            return city.toString();
          }
        }
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    // Offline fallback: check nearest known town within 6 km
    String? nearestTown;
    double minKm = 999.0;
    for (final entry in _knownTowns.entries) {
      final d = _distanceKm(lat, lon, entry.value.$1, entry.value.$2);
      if (d < minKm) {
        minKm = d;
        nearestTown = entry.key;
      }
    }
    if (nearestTown != null && minKm <= 6.0) {
      return nearestTown;
    }

    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
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
