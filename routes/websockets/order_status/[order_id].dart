import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

/// Stores active WebSocket connections for each order
final _orderConnections = <String, Set<WebSocketChannel>>{};

Future<Response> onRequest(RequestContext context, String orderId) async {
  final orderId = context.request.uri.pathSegments.last;

  final handler = webSocketHandler((channel, protocol) {
    // Add the new connection to the order's set
    _orderConnections
        .putIfAbsent(orderId, () => <WebSocketChannel>{})
        .add(channel);

    // Listen for messages from the client
    channel.stream.listen(
      (message) {
        _processMessage(channel, message, orderId);
      },
      onDone: () {
        // Remove connection when closed
        _orderConnections[orderId]?.remove(channel);
        if (_orderConnections[orderId]?.isEmpty ?? true) {
          _orderConnections.remove(orderId);
        }
      },
    );
  });

  return handler(context);
}

/// Processes an incoming message about order status updates
void _processMessage(
    WebSocketChannel channel, dynamic message, String orderId) {
  try {
    // Parse the incoming message
    final data = jsonDecode(message as String);

    if (data['type'] == 'order_status_update') {
      _broadcastOrderStatus(orderId, data as Map<String, dynamic>);
    } else {
      channel.sink.add(jsonEncode({'error': 'Invalid order status format'}));
    }
  } catch (e) {
    channel.sink.add(jsonEncode({'error': 'Invalid JSON format'}));
  }
}

/// Broadcasts order status updates to connected clients
void _broadcastOrderStatus(String orderId, Map<String, dynamic> data) {
  final connections = _orderConnections[orderId];
  if (connections != null) {
    for (final client in connections) {
      client.sink.add(jsonEncode(data));
    }
  }
}
