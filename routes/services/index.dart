import 'dart:developer';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _getServices(context),
    HttpMethod.post => _createService(context),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed))
  };
}

Future<Response> _getServices(RequestContext context) async {
  final serviceList = <Map<String, dynamic>>[];
  try {
    final firestore = Firestore.instance.collection('services');

    await firestore.get().then((documents) {
      for (final doc in documents) {
        serviceList.add(doc.map);
      }
    });

    return Response.json(body: serviceList.toString());
  } catch (e) {
    log('ERROR: $e');
    return Response.json(
      body: {'error': 'Internal Server Error', 'details': e.toString()},
      statusCode: 500,
    );
  }
}

Future<Response> _createService(RequestContext context) async {
  final body =  context.request.json as Map<String, dynamic>;
  final title = body['title'] as String;
  final category = body['category'] as String;
  final highCourtFee = body['highCourtFee'] as double;
  final magistrateFee = body['magistrateFee'] as double;

  final id = await Firestore.instance.collection('services').add({
    'title': title,
    'category': category,
    'highCourtFee': highCourtFee,
    'magistrateFee': magistrateFee,
  }).then((doc) async{
    await Firestore.instance.collection('services').document(doc.id).update({
      'id': doc.id,
    }); 
    return doc.id;
  });

  return Response.json(body: 
  {'message': 'successfully uploaded a service: $id'},
  );
}
