import 'package:dio/dio.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient({ApiConfig? config})
      : _config = config ?? ApiConfig.fromBaseUrl(defaultBaseUrl) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, dynamic>{'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
    ));
  }

  static const String defaultBaseUrl = 'http://120.26.30.221';

  final ApiConfig _config;
  late final Dio _dio;
  String? _token;

  Dio get dio => _dio;
  ApiConfig get config => _config;

  void updateAuthToken(String? token) {
    _token = token;
  }
}
