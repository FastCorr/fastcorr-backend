import 'dart:async';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

class HeartbeatManager {
  factory HeartbeatManager() => _instance;

  HeartbeatManager._internal();
  static final HeartbeatManager _instance = HeartbeatManager._internal();

  final _lastPingTimestamps = <WebSocketChannel, DateTime>{};
  Timer? _timer;

  void start() {
    if (_timer != null) return; // Prevent multiple timers

    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      final now = DateTime.now();
      for (final channel in _lastPingTimestamps.keys.toList()) {
        final lastPing = _lastPingTimestamps[channel]!;
        if (now.difference(lastPing) > const Duration(seconds: 30)) {
          channel.sink.close();
          _lastPingTimestamps.remove(channel);
        }
      }
    });
  }

  void updatePing(WebSocketChannel channel) {
    _lastPingTimestamps[channel] = DateTime.now();
  }

  void removeChannel(WebSocketChannel channel) {
    _lastPingTimestamps.remove(channel);
  }
}
