import 'package:dart_frog/dart_frog.dart';

import '../../services/paystack_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  try {
    final body = await context.request.json();

    final name = body['name']?.toString();
    final accountNumber = body['account_number']?.toString();
    final bankCode = body['bank_code']?.toString();

    // Validation
    if (name == null || accountNumber == null || bankCode == null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'Missing required fields: name, account_number, or bank_code'
        },
      );
    }

    final paystack = context.read<PaystackService>();

    final result = await paystack.createRecipient(
      name: name,
      accountNumber: accountNumber,
      bankCode: bankCode,
    );

    // Check for success
    final status = result['status'] == true;
    final data = result['data'];

    if (!status || data == null || data['recipient_code'] == null) {
      return Response.json(
        statusCode: 500,
        body: {
          'error': 'Paystack did not return a valid recipient',
          'paystack_response': result,
        },
      );
    }

    return Response.json(body: {
      'status'
      'recipient_code': data['recipient_code'],
      'message': 'Recipient created successfully',
      'data': data, 
    });
  } catch (e, s) {
    return Response.json(
      statusCode: 500,
      body: {
        'error': 'Failed to create recipient: $e',
        'stacktrace': s.toString(),
      },
    );
  }
}



