import 'package:firedart/firedart.dart';

class FirestoreService {
  final CollectionReference _drivers = Firestore.instance.collection('drivers');

  Future<List<Map<String, dynamic>>> getAvailableDrivers() async {
    try {
      final snapshot =
          await _drivers.where('status', isEqualTo: 'available').get();

      final drivers = snapshot
          .map((doc) {
            final data = doc.map;
            final fcmToken = data['fcmToken'];
            final driverLocation = data['currentLocation'];

            if (fcmToken != null && driverLocation is GeoPoint) {
              return {
                'fcmToken': fcmToken,
                'driverLocation': driverLocation,
              };
            }

            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      return drivers;
    } catch (e) {
      print('🔥 Error fetching available driver tokens: $e');
      return [];
    }
  }

  Future<void> uploadDriverLocation(GeoPoint geopoint, String driverId) async {
    try {
      await _drivers.document(driverId).update({
        'currentLocation': geopoint,
      });
    } catch (e) {
      rethrow;
    }
  }
}
