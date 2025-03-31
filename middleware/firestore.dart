import 'package:dart_frog/dart_frog.dart';
import 'package:firedart/firedart.dart';

Middleware firestoreInit() {
  return (handler) {
    return (context) async {
      if (!Firestore.initialized) {
        Firestore.initialize('fast-corr');
      }

      final response = await handler(context);

      return response;
    };
  };
}
