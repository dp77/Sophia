import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger_interceptor.dart';
import 'package:talker_dio_logger/talker_dio_logger_settings.dart';
import 'secure_api_client.dart';

class DioClient {
  static Dio? _dioInstance;

  static Dio get dio {
    if (_dioInstance == null) {
      throw Exception('DioClient not initialized. Call DioClient.initialize() first.');
    }
    return _dioInstance!;
  }

  static Future<void> initialize(SecureApiClient secureApiClient) async {
    _dioInstance = await _initializeDio(secureApiClient);
  }

  static Future<Dio> _initializeDio(SecureApiClient secureApiClient) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: "https://shuchiai.com/companion/app_new",
        receiveTimeout: const Duration(seconds: 150),
        connectTimeout: const Duration(seconds: 150),
        sendTimeout: const Duration(seconds: 150),
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(secureApiClient.createInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(
        TalkerDioLogger(
          settings: const TalkerDioLoggerSettings(
            printRequestHeaders: true,
            printResponseMessage: true,
            printErrorData: true,
            printRequestData: true,
            printErrorMessage: true,
            printResponseTime: true,
          ),
        ),
      );
    }
    return dio;
  }
}
