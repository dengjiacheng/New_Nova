import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/execution_asset.dart';
import '../../platform/app_logger.dart';
import '../api/api_client.dart';

abstract class AssetApiClient {
  Future<UploadAssetResponse> uploadFile({
    required String filePath,
    required Map<String, String> headers,
  });

  Future<void> deleteAsset(String assetId);
}

class NoopAssetApiClient implements AssetApiClient {
  NoopAssetApiClient({AppLogger? logger})
      : _logger = logger ?? AppLogger.defaultLogger();

  final AppLogger _logger;

  @override
  Future<void> deleteAsset(String assetId) async {
    await _logger.warning('NoopAssetApiClient.deleteAsset($assetId) called');
  }

  @override
  Future<UploadAssetResponse> uploadFile({
    required String filePath,
    required Map<String, String> headers,
  }) async {
    await _logger.warning('Noop upload for $filePath, returning dummy asset');
    return UploadAssetResponse(
      assetId: 'asset-$filePath',
      downloadUrl: 'noop://$filePath',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      checksum: 'noop',
    );
  }
}

class HttpAssetApiClient implements AssetApiClient {
  HttpAssetApiClient({
    required ApiClient apiClient,
    AppLogger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? AppLogger.defaultLogger();

  final ApiClient _apiClient;
  final AppLogger _logger;

  @override
  Future<void> deleteAsset(String assetId) async {
    try {
      await _apiClient.dio.delete<void>('/api/executions/assets/$assetId');
    } on DioException catch (error) {
      await _logger.error('Failed to delete asset $assetId', cause: error);
    }
  }

  @override
  Future<UploadAssetResponse> uploadFile({
    required String filePath,
    required Map<String, String> headers,
  }) async {
    final File file = File(filePath);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      ...headers,
    });
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/executions/assets',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final Map<String, dynamic> data =
        (response.data?['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return UploadAssetResponse(
      assetId: data['assetId'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      expiresAt: DateTime.parse(
          data['expiresAt'] as String? ?? DateTime.now().toUtc().toIso8601String()),
      checksum: data['checksum'] as String? ?? headers['X-Checksum'] ?? '',
    );
  }
}
