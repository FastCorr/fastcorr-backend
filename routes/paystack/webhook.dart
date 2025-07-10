import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import '../../services/paystack_service.dart';
import '../../services/services.dart';

/// This endpoint listens for incoming webhook events from Paystack.
Future<Response> onRequest(RequestContext context) async {
  // 1. Only accept POST requests
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  
 // 2. Read the raw request body stream into a single list of bytes
  final requestBytes = await context.request.bytes().fold<List<int>>(
    <int>[],
    (previous, current) => previous..addAll(current),
  );

// Now that we have the complete list, we can decode it
  final requestBody = utf8.decode(requestBytes); // For parsing JSON later

  // 3. Get the signature from the request headers
  final signature = context.request.headers['x-paystack-signature'];
  if (signature == null) {
    // No signature, refuse the request
    return Response(
        statusCode: HttpStatus.unauthorized, body: 'Missing Signature');
  }

  // 4. Securely verify the signature
  if (!_isSignatureValid(signature, requestBytes)) {
    // Invalid signature, refuse the request
    return Response(
        statusCode: HttpStatus.unauthorized, body: 'Invalid Signature');
  }

  // --- At this point, the request is verified as genuinely from Paystack ---

  // 5. Acknowledge receipt immediately with a 200 OK response.
  // This is crucial. If Paystack doesn't get a 200, it will keep retrying.
  // We process the data *after* sending the response.
  _processWebhookEvent(context, requestBody)
      .ignore(); // Process in the background

  // ignore: avoid_redundant_argument_values
  return Response(statusCode: HttpStatus.ok);
}

/// Verifies the webhook signature using your Paystack Secret Key.
bool _isSignatureValid(String signature, List<int> requestBodyBytes) {
  final paystackKey = EnvConfig.paystackSecretKey;
  final hmac = Hmac(sha512, utf8.encode(paystackKey));
  final digest = hmac.convert(requestBodyBytes);
  final calculatedSignature = digest.toString();
  return signature == calculatedSignature;
}

/// Asynchronously processes the event data.
Future<void> _processWebhookEvent(
    RequestContext context, String requestBody,) async {
  try {
    final eventData = jsonDecode(requestBody) as Map<String, dynamic>;
    final eventType = eventData['event'] as String?;

    // We only care about successful charges for now.
    if (eventType == 'charge.success') {
      final data = eventData['data'] as Map<String, dynamic>;
      final reference = data['reference'] as String?;

      if (reference != null) {
        log('Webhook received for successful charge: $reference');

        // Use the PaystackService to get the full, verified transaction details.
        final paystackService = context.read<PaystackService>();
        final transaction = await paystackService.verifyTransaction(reference);

        // Here you would have the logic to update your database.
        // It's important to check if you've already processed this reference
        // to avoid duplicate updates (in case the user redirect also worked).

        // Example:
        // final orderStatus = await getOrderStatusFromDb(transaction.reference);
        // if (orderStatus != 'paid') {
        //   await updateOrderAsPaidInDb(transaction);
        // }
      }
    }
  } catch (e) {
    // Log any errors during processing.
    log('Error processing webhook event: $e');
  }
}
