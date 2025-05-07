import 'dart:convert';
import 'package:http/http.dart' as http;

class PaystackService {

  PaystackService(this.secretKey);
  final String secretKey;

  Future<Map<String, dynamic>> createRecipient({
    required String name,
    required String accountNumber,
    required String bankCode,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.paystack.co/transferrecipient'),
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
      Uri.parse('https://api.paystack.co/transfer'),
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
