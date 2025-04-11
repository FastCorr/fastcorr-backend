// lib/src/routes/calculate.dart
// ignore_for_file: avoid_dynamic_calls

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    try {
      final body = await context.request.json();
      final courtTypeId = body['courtTypeId'] as String;
      final actionId = body['actionId'] as String;

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

Future<dynamic> _calculateAdminAndActionFees(
  String courtTypeId,
  String actionId,
) async {
  try {
    final courtDoc = await Firestore.instance
        .collection('court_types')
        .where('courtTypeId', isEqualTo: courtTypeId)
        .get();

    final actionDoc = await Firestore.instance
        .collection('actions')
        .where('actionId', isEqualTo: actionId)
        .get();

    final courtFee = courtDoc.first.map['adminFee'];
    final actionFee = actionDoc.first.map['actionFee'];

    if (courtFee == null || actionFee == null) {
      throw Exception('Missing adminFee or actionFee in Firestore document');
    }

    return courtFee + actionFee;
  } catch (e) {
    // Rethrow the exception to be caught in the onRequest function.
    rethrow;
  }
}
