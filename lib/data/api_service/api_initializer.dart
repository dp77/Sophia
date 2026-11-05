import 'dio_client.dart';
import 'secure_api_client.dart';

class ApiInitializer {
  static SecureApiClient? _secureApiClient;

  /// Get the secure API client instance
  static SecureApiClient? get secureApiClient => _secureApiClient;

  /// Initialize API client
  /// Call this once at app startup (e.g., in main.dart or splash screen)
  /// Note: Firebase Auth should be initialized before calling this
  static Future<void> initialize() async {
    final apiKey = await SecureApiClient.getApiKey();

    _secureApiClient = SecureApiClient(apiKey: apiKey);
    await _secureApiClient!.init();

    await DioClient.initialize(_secureApiClient!);
  }
}
