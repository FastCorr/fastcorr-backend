// lib/src/routes/calculate.dart
// ignore_for_file: avoid_dynamic_calls

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    try {
      final body = await context.request.json();
      final courtTypeId = body['courtTypeId'] as String?;
      final actionId = body['actionId'] as String?;

      if (courtTypeId == null || actionId == null) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'Missing courtTypeId or actionId'},
        );
      }

      final price = await _calculateAdminAndActionFees(
        courtTypeId,
        actionId,
      );

      return Response.json(body: {'price': price});
    } catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Failed to calculate price: $e'},
      );
    }
  } else {
    return Response(statusCode: 405);
  }
}

Future<double> _calculateAdminAndActionFees(
  String courtTypeId,
  String actionId,
) async {
  try {
    final courtDoc = await Firestore.instance
        .collection('court_types')
        .document(courtTypeId)
        .get();

    final actionDoc =
        await Firestore.instance.collection('actions').document(actionId).get();

    final courtFee = courtDoc.map['adminFee'] as double?;
    final actionFee = actionDoc.map['actionFee'] as double?;

    if (courtFee == null || actionFee == null) {
      throw Exception('Missing adminFee or actionFee in Firestore document');
    }

    return courtFee + actionFee;
  } catch (e) {
    // Rethrow the exception to be caught in the onRequest function.
    rethrow;
  }
}
