import 'package:dart_frog/dart_frog.dart';
import '../../services/paystack_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
 

  try {
     final body = await context.request.json();
  

    final paystack = context.read<PaystackService>();

    final result = await paystack.initiateTransfer(
      amount: body['amount'] as int,
      recipientCode: body['recipient'] as String,
      reason: body['reason'] as String,
    );

    return Response.json(body: result);
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Failed to initiate transfer: $e'},
    );
  }
}
