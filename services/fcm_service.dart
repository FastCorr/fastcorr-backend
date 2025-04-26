import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;

class FcmService {

final env = DotEnv()..load();


  Future<void> sendOrderNotification({
    required List<String> tokens,
    required String orderId,
    required String clientName,
  }) async {
    final serverKey = env['FCM_SERVER_KEY'] ?? '';

    if (serverKey.isEmpty) {
      print('❌ FCM server key is missing.');
      return;
    }

    if (tokens.isEmpty) {
      print('⚠️ No FCM tokens to send notification to.');
      return;
    }

    final message = {
      'notification': {
        'title': '🚗 New Delivery Order',
        'body': 'Pickup from $clientName',
      },
      'data': {
        'orderId': orderId,
      },
      'registration_ids': tokens,
    };

    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('✅ Notification sent to ${tokens.length} driver(s)');
    } else {
      print('❌ Failed to send notification: ${response.body}');
    }
  }
}
