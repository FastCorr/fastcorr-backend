import 'dart:convert';

import 'package:firedart/firestore/models.dart';
import 'package:geodesy/geodesy.dart';
import 'package:http/http.dart' as http;

import 'services.dart';


class GeocodingService {
  final String _apiKey = EnvConfig.googleAPIKey;
  final Geodesy geodesy = Geodesy();
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    if (_apiKey.isEmpty) {
      print('❌ Missing Google Maps API key');
      return null;
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(address)}&key=$_apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List?;

      if (results != null && results.isNotEmpty) {
        final location = results[0]['geometry']['location'];
        return {
          'lat': location['lat'] as double,
          'lng': location['lng'] as double,
        };
      } else {
        print('⚠️ No results found for address: $address');
      }
    } else {
      print('❌ Google Geocoding API failed: ${response.body}');
    }

    return null;
  }

  List<Map<String, dynamic>> filterDriversWithinRadius({
    required List<Map<String, dynamic>> drivers,
    required double pickupLat,
    required double pickupLng,
    required double radiusKm,
  }) {
    final pickupPoint = LatLng(pickupLat, pickupLng);

    return drivers.where((driver) {
      final location = driver['currentLocation'] as GeoPoint;

      final driverPoint = LatLng(location.latitude, location.longitude);
      final distanceMeters =
          geodesy.distanceBetweenTwoGeoPoints(pickupPoint, driverPoint);

      return distanceMeters <= radiusKm * 1000;
    }).toList();
  }


/// This function calculates the distance in meters between two coordinates.
  /// Using the Haversine formula which is a formula used to calculate
  /// the distance two points on a sphere (such as the Earth)
  ///  given their longitudes latitudes.
  double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}
