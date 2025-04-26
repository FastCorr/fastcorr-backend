import 'package:dart_frog/dart_frog.dart';

import '../../services/paystack_service.dart';
import '../../services/recipient_cache.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  try{
final body = await context.request.json();
    final paystack = context.read<PaystackService>();
    final cache = context.read<RecipientCache>();

    final key = '${body['account_number']}_${body['bank_code']}';
    if (cache.contains(key)) {
      return Response.json(body: {
        'status': true,
        'message': 'Recipient already cached',
        'recipient_code': cache.get(key),
      });
    }

    final result = await paystack.createRecipient(
      name: body['name'] as String,
      accountNumber: body['account_number'] as String,
      bankCode: body['bank_code'] as String,
    );

    if (result['status'] == true) {
      final recipientCode = result['data']['recipient_code'] as String;
      cache.set(key, recipientCode);
    }

    return Response.json(body: result);

  }catch (e, s){
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to create recipient: $e : Stacktrace: $s'},
    );
  }
  
}
