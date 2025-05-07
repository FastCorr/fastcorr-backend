import 'dart:io';

class EnvConfig {
  static String get paystackSecretKey =>
      Platform.environment['PAYSTACK_SECRET_KEY'] ?? '';

  static String get googleAPIKey =>
      Platform.environment['GOOGLE_API_KEY'] ?? '';

  static String get fcmServerKey => 
      Platform.environment['FCM_SERVER_KEY'] ?? '';
}
