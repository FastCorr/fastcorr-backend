import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';

import '../../services/services.dart';

final firestoreService = FirestoreService();
final geocodingService = GeocodingService();
final fcmService = FcmService();

Future<Response> onRequest(RequestContext context) async {
  try {
    final body = await context.request.body();
    final data = json.decode(body);

    final orderId = data['id'] as String;
    final pickupLat = data['pickupLat'] as double;
    final pickupLng = data['pickupLng'] as double;

    if (orderId.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Missing orderId'},
      );
    }

    // Step 2: Get available drivers
    final allDrivers = await firestoreService.getAvailableDrivers();

    // Step 3: Filter drivers within radius (e.g. 5 km)
    final nearbyDrivers = geocodingService.filterDriversWithinRadius(
      drivers: allDrivers,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      radiusKm: 10,
    );

    final tokens = nearbyDrivers.map((d) => d['fcmToken'] as String).toList();

    if (tokens.isEmpty) {
      return Response.json(
        body: {'message': 'No nearby available drivers'},
        statusCode: 404,
      );
    }

    // Step 4: Send notifications
    await fcmService.sendOrderNotification(
      tokens: tokens,
      orderId: orderId,
      clientName: data['clientName'] as String,
    );

    return Response.json(body: {
      'success': true,
      'notified': tokens.length,
    });
  } catch (e, s) {
    return Response.json(statusCode: 500, body: {'error: $e': s.toString()});
  }
}
