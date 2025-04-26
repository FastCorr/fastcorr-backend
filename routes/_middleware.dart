// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;

import '../middleware/firestore.dart';
import '../services/paystack_service.dart';
import '../services/recipient_cache.dart';

final env = DotEnv()..load();
final paystackService = PaystackService(env['PAYSTACK_SECRET_KEY']!);
final apiKey = env['GOOGLE_API_KEY'] ?? '';
final recipientCache = RecipientCache();

Handler middleware(Handler handler) {
  return handler
      .use(corsMiddleware)
      .use(firestoreInit())
      .use(provider<PaystackService>((_) => paystackService))
      .use(provider<RecipientCache>((_) => recipientCache));
}

Middleware corsMiddleware = (handler) {
  return (context) async {
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: _corsHeaders);
    }
    final response = await handler(context);
    return response.copyWith(headers: {...response.headers, ..._corsHeaders});
  };
};

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.json(
          statusCode: 401,
          body: {'error': ' Missing or invalid authorization header'},
        );
      }

      final token = authHeader.substring(7);

      try {
        /// verify ID using Firebase Auth rest api
        final userId = await verifyFirebaseToken(token);

        if (userId == null) {
          return Response.json(
            statusCode: 401,
            body: {'error': 'Invalid or expired Firebase token'},
          );
        }
        return handler(context);
      } catch (e) {
        print('firebase auth error: $e');
        return Response.json(
          statusCode: 500,
          body: {'error': 'unAuthorized: invalid token'},
        );
      }
    };
  };
}

Future<String?> verifyFirebaseToken(String token) async {
  final url = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=$apiKey',
  );

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': token}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['users'] != null) {
        return data['users'][0]['localId'] as String;
      }
    }
    return null;
  } catch (e) {
    log('Error verifying Firebase token: $e');
    return null;
  }
}
