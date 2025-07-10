import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import '../../services/paystack_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // Ensure the request method is POST.
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Access the PaystackService instance.
  final paystackService = context.read<PaystackService>();

  try {
    // Read the request body.
    final body = await context.request.json() as Map<String, dynamic>;
    final reference = body['reference'] as String?;

    if (reference == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'Transaction reference is required.'},
      );
    }

    // Call the service to verify the transaction.
    final result = await paystackService.verifyTransaction(reference);

    // Return the successful verification details to the client.
    return Response.json(body: result);
  } catch (e) {
    // Handle errors.
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': e.toString()},
    );
  }
}
