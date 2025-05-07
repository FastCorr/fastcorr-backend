// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

import '../../../services/services.dart';

final _driverConnections = <String, Set<WebSocketChannel>>{};
final _lastDriverLocations = <String, Map<String, double>>{};

final _heartbeat = HeartbeatManager()..start();
final _geocodingServ = GeocodingService();

Future<Response> onRequest(RequestContext context, String driverId) async {
  final driverId = context.request.uri.pathSegments.last;

  final handler = webSocketHandler((channel, protocol) {
    _driverConnections
        .putIfAbsent(driverId, () => <WebSocketChannel>{})
        .add(channel);
    _heartbeat.updatePing(channel);

    channel.stream.listen(
      (message) {
        _handleMessage(channel, message, driverId);
      },
      onDone: () {
        _driverConnections[driverId]?.remove(channel);

        if (_driverConnections[driverId]?.isEmpty ?? true) {
          _driverConnections.remove(driverId);
          _lastDriverLocations.remove(driverId);
        }
        _heartbeat.removeChannel(channel);
      },
    );
  });

  return handler(context);
}

void _handleMessage(
  WebSocketChannel channel,
  dynamic message,
  String driverId,
) {
  try {
    _heartbeat.updatePing(channel);

    final data = jsonDecode(message as String);

    final type = data['type'];
    if (type == 'ping') {
      channel.sink.add(jsonEncode({'type': 'pong'}));
      _heartbeat.updatePing(channel);

      return;
    }

    if (type == 'location_update') {
      final newLat = (data['lat'] as num).toDouble();
      final newLng = (data['lng'] as num).toDouble();

      if (_lastDriverLocations.containsKey(driverId)) {
        final lastLat = _lastDriverLocations[driverId]!['lat']!;
        final lastLng = _lastDriverLocations[driverId]!['lng']!;

        final distance = _geocodingServ
        .calculateDistance(lastLat, lastLng, newLat, newLng);

        if (distance >= 100) {
          _lastDriverLocations[driverId] = {'lat': newLat, 'lng': newLng};
          _broadcastLocationUpdate(driverId, data as Map<String, dynamic>);
        }
      } else {
        _lastDriverLocations[driverId] = {'lat': newLat, 'lng': newLng};
        _broadcastLocationUpdate(driverId, data as Map<String, dynamic>);
      }
    } else {
      channel.sink.add(jsonEncode({'error': 'Invalid location data format'}));
    }
  } catch (e) {
    channel.sink.add(jsonEncode({'error': 'Invalid JSON format'}));
  }
}

void _broadcastLocationUpdate(String driverId, Map<String, dynamic> data) {
  final connections = _driverConnections[driverId];
  if (connections != null) {
    for (final client in connections) {
      client.sink.add(jsonEncode(data));
    }
  }
}
