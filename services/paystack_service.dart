import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PaystackService {

  PaystackService(this.secretKey);
  final String secretKey;

  
  static const _uuid = Uuid();
  static const String _baseUrl = 'https://api.paystack.co';

 
    /// Prepares a transaction and gets an authorization_url for redirection.
  Future<Map<String, dynamic>> initializeTransaction({
    required double amount,
    required String email,
    required String callbackUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/transaction/initialize');
    final txRef = 'fastcorr_${_uuid.v4()}';

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        // Paystack expects amount in the lowest currency unit (kobo/cents).
        'amount': (amount * 100).toInt().toString(),
        'currency': 'ZAR',
        'callback_url': callbackUrl,
        'reference': txRef,
      }),
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
          responseBody['message'] ?? 'Failed to initialize transaction');
    }
    return responseBody;
  }

  /// Verifies a transaction's status after the user is redirected back to the app.
  Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    final uri = Uri.parse('$_baseUrl/transaction/verify/$reference');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $secretKey'},
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
          responseBody['message'] ?? 'Failed to verify transaction');
    }
    return responseBody;
  }


  Future<Map<String, dynamic>> createRecipient({
    required String name,
    required String accountNumber,
    required String bankCode,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/transferrecipient'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': 'basa',
        'name': name,
        'account_number': accountNumber,
        'bank_code': bankCode,
        'currency': 'ZAR',
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

 
  Future<Map<String, dynamic>> initiateTransfer({
    required int amount,
    required String recipientCode,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/transfer'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'source': 'balance',
        'amount': amount,
        'recipient': recipientCode,
        'reason': reason,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
