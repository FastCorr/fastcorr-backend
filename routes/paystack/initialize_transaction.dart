import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../services/paystack_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // Ensure the request method is POST.
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Access the PaystackService instance provided by the middleware.
  final paystackService = context.read<PaystackService>();

  try {
    // Read and decode the request body from the client.
    final body = await context.request.json() as Map<String, dynamic>;
    final email = body['email'] as String?;
    final amount = body['amount'] as num?;
    final callbackUrl = body['callback_url'] as String?;


    if (email == null || amount == null || callbackUrl == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'callbackUrl, Email and amount are required.'},
      );
    }

    // Call the service to initialize the transaction.
    final result = await paystackService.initializeTransaction(
      amount: amount.toDouble(),
      email: email,
      callbackUrl: callbackUrl,
    );

    // Return the successful response from Paystack to the client.
    return Response.json(body: result);
  } catch (e) {
    // Handle any errors from the service or JSON parsing.
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': e.toString()},
    );
  }
}
