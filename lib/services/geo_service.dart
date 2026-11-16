import 'dart:math' as math;
import 'url_launcher_stub.dart'
    if (dart.library.html) 'url_launcher_web.dart';

class GeoCoordinates {
  final double latitude;
  final double longitude;

  const GeoCoordinates(this.latitude, this.longitude);
}

class GeoService {
  /// Known GPS coordinates for Arua City support points
  static const Map<String, GeoCoordinates> aruaCoordinates = {
    'muni-clinic': GeoCoordinates(3.0031, 30.9125),
    'arua-hospital': GeoCoordinates(3.0205, 30.9110),
    'ediofe-school': GeoCoordinates(3.0336, 30.8988),
    'st-marys-school': GeoCoordinates(3.0185, 30.9250),
    'ceford-ngo': GeoCoordinates(3.0240, 30.9150),
    'oli-primary': GeoCoordinates(3.0298, 30.9172),
  };

  /// Reference coordinate for Arua Central / Town Center
  static const GeoCoordinates aruaCenter = GeoCoordinates(3.0210, 30.9115);

  /// Standard reference GPS coordinates for sub-counties and divisions across Arua
  static const Map<String, GeoCoordinates> subCountyCoordinates = {
    'Arua Central': GeoCoordinates(3.0210, 30.9115),
    'Arua Hill': GeoCoordinates(3.0185, 30.9250),
    'Ediofe': GeoCoordinates(3.0336, 30.8988),
    'Oli': GeoCoordinates(3.0298, 30.9172),
    'Ayivu': GeoCoordinates(3.0450, 30.9100),
    'Dadamu': GeoCoordinates(3.0550, 30.9300),
    'Manibe': GeoCoordinates(3.0620, 30.9450),
    'Muni': GeoCoordinates(3.0031, 30.9125),
    'Logiri': GeoCoordinates(2.9200, 30.8800),
    'Offaka': GeoCoordinates(2.8700, 31.0200),
  };

  /// Dynamic registry for runtime-captured GPS coordinates of schools, hospitals, and dispensing centers
  static final Map<String, GeoCoordinates> _customCoordinates = {};

  /// Retrieves the GPS coordinates for a specific sub-county in Arua
  static GeoCoordinates getCoordinatesForSubCounty(String? subCounty) {
    if (subCounty != null && subCountyCoordinates.containsKey(subCounty)) {
      return subCountyCoordinates[subCounty]!;
    }
    return aruaCenter;
  }

  /// Registers or updates the GPS coordinates captured for any school, hospital, or dispensing center
  static void registerFacilityCoordinates(String facilityIdOrName, double latitude, double longitude) {
    final coord = GeoCoordinates(latitude, longitude);
    _customCoordinates[facilityIdOrName] = coord;
    _customCoordinates[facilityIdOrName.toLowerCase()] = coord;
  }

  /// Resolves GPS coordinates for a facility ID or name, checking custom entries, known points, and sub-county defaults
  static GeoCoordinates getFacilityCoordinates(String facilityIdOrName, {String? subCounty}) {
    if (_customCoordinates.containsKey(facilityIdOrName)) {
      return _customCoordinates[facilityIdOrName]!;
    }
    final lower = facilityIdOrName.toLowerCase();
    if (_customCoordinates.containsKey(lower)) {
      return _customCoordinates[lower]!;
    }
    if (aruaCoordinates.containsKey(facilityIdOrName)) {
      return aruaCoordinates[facilityIdOrName]!;
    }
    if (aruaCoordinates.containsKey(lower)) {
      return aruaCoordinates[lower]!;
    }
    if (subCounty != null && subCountyCoordinates.containsKey(subCounty)) {
      return subCountyCoordinates[subCounty]!;
    }
    return aruaCenter;
  }

  /// Calculates real walking/driving distance in kilometers using the Haversine formula
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((earthRadiusKm * c).toStringAsFixed(1));
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Builds a Google Maps turn-by-turn navigation link
  static String getNavigationUrl({
    required double latitude,
    required double longitude,
    required String destinationName,
  }) {
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
  }

  /// Builds a direct Google Maps pin link with location name
  static String getPlaceUrl({
    required double latitude,
    required double longitude,
    required String destinationName,
  }) {
    final query = Uri.encodeComponent('$destinationName, Arua, Uganda');
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude+($query)';
  }

  /// Opens live turn-by-turn walking/driving directions directly in Google Maps
  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
    required String destinationName,
  }) async {
    final url = getNavigationUrl(
      latitude: latitude,
      longitude: longitude,
      destinationName: destinationName,
    );
    try {
      openExternalUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the facility pin directly in Google Maps
  static Future<bool> openPlace({
    required double latitude,
    required double longitude,
    required String destinationName,
  }) async {
    final url = getPlaceUrl(
      latitude: latitude,
      longitude: longitude,
      destinationName: destinationName,
    );
    try {
      openExternalUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
