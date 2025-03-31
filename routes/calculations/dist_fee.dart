// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';
import 'package:http/http.dart' as http;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    final body = await context.request.json();
    final partyAddresses = body['partyAddresses'] as List<String>;
    final city = body['city'] as String;

    try {
      final price = await _calculateDistanceFee(
        city,
        partyAddresses,
      );

      return Response.json(body: {'price': price});
    } catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Failed to calculate distance cost: $e'},
      );
    }
  } else {
    return Response(statusCode: 405);
  }
}

Future<double> _calculateDistanceFee(
  String city,
  List<String> partyAddresses,
) async {
  final pricingDoc =
      await Firestore.instance.collection('pricing')
      .document('9XlHdo2ME5tjyKKuHdSE').get();
  final pricePerKm = pricingDoc.map['pricePerKm'] as double;

  final officeDoc = await _getOfficeByCity(city);
 
  double totalDistanceFee = 0;
  for (final address in partyAddresses) {
    try {

      final distance = await _calculateDistance(officeDoc.map['address'] as String, address,);
      if (distance > 15000) {
        // 15km in meters
        totalDistanceFee += (distance - 15000) / 1000 * pricePerKm;
      }
    } catch (e) {
      log('Geocoding error for address "$address": $e');
      rethrow;
    }
  }
  return totalDistanceFee;
}

Future<double> _calculateDistance(
    String originAddress, String destinationAddress) async {
  const apiKey = 'AIzaSyDFwGUREhbc3YZS0uvVkR5At_CK5hnINxM'; // Replace with your actual API key
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/distancematrix/json?'
    'origins=${Uri.encodeComponent(originAddress)}&'
    'destinations=${Uri.encodeComponent(destinationAddress)}&'
    'key=$apiKey',
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    
    if (data['rows'] != null &&
        data['rows'][0]['elements'] != null &&
        data['rows'][0]['elements'][0]['status'] == 'OK') {
      final distance =
          data['rows'][0]['elements'][0]['distance']['value'] as int;
      return distance.toDouble();
    } else {
      
      var errorMessage = 'Distance calculation failed. ';
      if (data['rows'] == null || data['rows'] == null) {
        errorMessage += 'Rows data missing or empty.';
      } else if (data['rows'][0]['elements'] == null ||
          data['rows'][0]['elements'] == null) {
        errorMessage += 'Elements data missing or empty.';
      } else {
        errorMessage += 'Status: ${data['rows'][0]['elements'][0]['status']}';
      }

      throw Exception(errorMessage);
    }
  } else {
    throw Exception('Failed to load distance: ${response.statusCode}');
  }
}

Future<Document> _getOfficeByCity(String city) async {
  final officesCollection = Firestore.instance.collection('offices');
  final query = await officesCollection.where('city', isEqualTo: city).get();

  if (query.isNotEmpty) {
    return query.first; // Return the first matching office
  } else {
    throw Exception('Office not found for city: $city');
  }
}

// Future<Map<String, double>> _geocodeAddress(String address) async {
//   const apiKey = 'AIzaSyDFwGUREhbc3YZS0uvVkR5At_CK5hnINxM';
//   final url = Uri.parse(
//     'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$apiKey',
//   );

//   final response = await http.get(url);
//   if (response.statusCode == 200) {
//     final data = json.decode(response.body);
//     if (data['status'] == 'OK' && data['results'] == null) {
//       final location = data['results'][0]['geometry']['location'];
//       return {
//         'latitude': location['lat'] as double,
//         'longitude': location['lng'] as double,
//       };
//     } else {
//       throw Exception(
//           'Geocoding failed: ${data['error_message'] ?? data['status']}');
//     }
//   } else {
//     throw Exception('Failed to load geocoding data: ${response.statusCode}');
//   }
// }
