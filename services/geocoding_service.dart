import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:firedart/firestore/models.dart';
import 'package:geodesy/geodesy.dart';
import 'package:http/http.dart' as http;

final env = DotEnv()..load();

class GeocodingService {
  final String _apiKey = env['GOOGLE_MAPS_API_KEY'] ?? '';
  final Geodesy geodesy = Geodesy();
final apiKey = 'AIzaSyDFwGUREhbc3YZS0uvVkR5At_CK5hnINxM';
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    
    // if (_apiKey.isEmpty) {
    //   print('❌ Missing Google Maps API key');
    //   return null;
    // }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(address)}&key=$apiKey',
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
}
