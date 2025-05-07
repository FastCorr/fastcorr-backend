import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

import '../../../services/services.dart';

final availableDrivers = <String, WebSocketChannel>{};
final lastKnownLocations = <String, Map<String, double>>{};


final _heartbeat = HeartbeatManager()..start();

Future<Response> onRequest(RequestContext context, String driverId) async {
  final driverId = context.request.uri.pathSegments.last;

  final handler = webSocketHandler((channel, protocol) {
    // Register driver as available
    availableDrivers[driverId] = channel;
    // _heartbeat.updatePing(channel);

    log('Driver $driverId connected for order notifications.');

    channel.stream.listen(
      (message) {
         try {
          final data = jsonDecode(message as String);
          if (data['type'] == 'location') {
            final lat = data['lat'] as double;
            final lng = data['lng'] as double;
            lastKnownLocations[driverId] = {'lat': lat, 'lng': lng};
          }
        } catch (_) {
          // Ignore bad messages
        }

        log('Received from $driverId: $message');
      },
      onDone: () {
        availableDrivers.remove(driverId);
         lastKnownLocations.remove(driverId);
        log('Driver $driverId disconnected.');
        _heartbeat.removeChannel(channel);
      },
    );
  });

  return handler(context);
}
