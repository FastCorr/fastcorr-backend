// ignore_for_file: lines_longer_than_80_chars, inference_failure_on_instance_creation

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:firedart/firedart.dart';

import '../../../services/services.dart';

final _driverConnections = <String, Set<WebSocketChannel>>{};
final _lastDriverLocations = <String, Map<String, double>>{};

final _lastFirestoreWrite = <String, DateTime>{};
const firestoreWriteInterval = Duration(minutes: 1);

final _heartbeat = HeartbeatManager()..start();
final _geocodingServ = GeocodingService();
final _firestoreServ = FirestoreService();

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

      final now = DateTime.now();
      final lastWrite = _lastFirestoreWrite[driverId];
      final shouldWrite = lastWrite == null ||
          now.difference(lastWrite) >= firestoreWriteInterval;

      if (shouldWrite) {
        _lastFirestoreWrite[driverId] = now;
        _uploadWithRetry(driverId, GeoPoint(newLat, newLng));
      }

      if (_lastDriverLocations.containsKey(driverId)) {
        final lastLat = _lastDriverLocations[driverId]!['lat']!;
        final lastLng = _lastDriverLocations[driverId]!['lng']!;

        final distance =
            _geocodingServ.calculateDistance(lastLat, lastLng, newLat, newLng);

        if (distance >= 50) {
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

// ignore: avoid_void_async
void _broadcastLocationUpdate(
    String driverId, Map<String, dynamic> data) async {
  final connections = _driverConnections[driverId];
  if (connections != null) {
    for (final client in connections) {
      client.sink.add(jsonEncode(data));
    }
  }
}

/// Uploads the driver's location to Firestore with exponential backoff.
///
/// If the upload fails, this function will retry up to [maxAttempts] times,
/// waiting [500 * 2^attempt] milliseconds between each attempt.
///
/// If all attempts fail, a log message is written with the number of attempts
/// and the error message.
///
/// [driverId] is the ID of the driver whose location is being uploaded.
///
/// [location] is the [GeoPoint] containing the driver's latitude and longitude.
Future<void> _uploadWithRetry(
  String driverId,
  GeoPoint location, {
  int attempt = 0,
  int maxAttempts = 5,
}) async {
  try {
    await _firestoreServ.uploadDriverLocation(location, driverId);
    log('📍 Firestore location uploaded for $driverId');
  } catch (e) {
    final delay =
        Duration(milliseconds: 500 * (1 << attempt)); // 0.5s, 1s, 2s, 4s...
    if (attempt < maxAttempts) {
      log('⚠️ Retry #$attempt for $driverId in ${delay.inMilliseconds}ms due to: $e');
      await Future.delayed(delay);
      await _uploadWithRetry(driverId, location, attempt: attempt + 1);
    } else {
      log('❌ Failed to upload location for $driverId after $maxAttempts attempts.');
    }
  }
}
