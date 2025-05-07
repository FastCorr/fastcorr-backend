import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import '../../routes/websockets/orders/[driver_id].dart' as driver_ws;
import '../../services/services.dart'; // Import driver WebSocket map

final _geocodingServ = GeocodingService();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final body = await context.request.body();
  final data = jsonDecode(body);


  final orderLat = data['lat'] as double?;
  final orderLng = data['lng'] as double?;
  final orderId = data['order_id'] ?? 'new_order';

  if (orderLat == null || orderLng == null) {
    return Response(statusCode: 400, body: 'Missing order lat/lng');
  }

  final orderPayload = {
    'type': 'new_order',
    'order_id': orderId,
    'lat': orderLat,
    'lng': orderLng,
    'message': 'You have a new order request!',
    'pickupAddress': 'pickupAddress',
  };

  // Broadcast to nearby drivers
  var sentTo = 0;
  driver_ws.availableDrivers.forEach((driverId, channel) {
    final driverLocation = driver_ws.lastKnownLocations[driverId];
    if (driverLocation != null) {
      final distance = _geocodingServ.calculateDistance(
        orderLat,
        orderLng,
        driverLocation['lat']!,
        driverLocation['lng']!,
      );
      if (distance <= 5000) {
        channel.sink.add(jsonEncode(orderPayload));
        sentTo++;
      }
    }
  });

  return Response.json(body: {
    'status': 'order_sent',
    'sent_to': sentTo,
  });
}
