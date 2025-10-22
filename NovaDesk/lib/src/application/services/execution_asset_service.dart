import 'dart:convert';
import 'dart:io';

import '../../data/clients/asset_api_client.dart';
import '../../domain/entities/execution_asset.dart';
import '../../domain/entities/template.dart';
import '../../platform/app_logger.dart';

class ExecutionAssetService {
  ExecutionAssetService({
    required AssetApiClient assetApiClient,
    AppLogger? logger,
    int maxFileSizeBytes = 50 * 1024 * 1024,
  })  : _assetApiClient = assetApiClient,
        _logger = logger ?? AppLogger.defaultLogger(),
        _maxFileSizeBytes = maxFileSizeBytes;

  final AssetApiClient _assetApiClient;
  final AppLogger _logger;
  final int _maxFileSizeBytes;

  Future<List<UploadedAsset>> uploadAssets(ScriptTemplate template) async {
    final List<UploadedAsset> uploaded = <UploadedAsset>[];
    for (final TemplateField field in template.fields) {
      if (field.type != 'file') {
        continue;
      }
      final String? path = field.value as String?;
      if (path == null || path.isEmpty) {
        throw AssetUploadException('文件字段 ${field.key} 缺少路径');
      }
      final File file = File(path);
      if (!await file.exists()) {
        throw AssetUploadException('文件不存在: $path');
      }
      final int length = await file.length();
      if (length > _maxFileSizeBytes) {
        throw AssetUploadException('文件超出大小限制(${_maxFileSizeBytes ~/ (1024 * 1024)}MB): $path');
      }
      final String checksum = await _calculateChecksum(file);
      final UploadAssetResponse response = await _assetApiClient.uploadFile(
        filePath: path,
        headers: <String, String>{'X-Checksum': checksum},
      );
      uploaded.add(
        UploadedAsset(
          fieldKey: field.key,
          assetId: response.assetId,
          checksum: checksum,
        ),
      );
    }
    return uploaded;
  }

  Future<void> cleanup(List<UploadedAsset> assets) async {
    for (final UploadedAsset asset in assets) {
      try {
        await _assetApiClient.deleteAsset(asset.assetId);
      } catch (error) {
        await _logger.warning('Failed to delete asset ${asset.assetId}: $error');
      }
    }
  }

  Future<String> _calculateChecksum(File file) async {
    final List<int> bytes = await file.readAsBytes();
    final String hex = base64Url.encode(bytes);
    return 'local:$hex';
  }
}

class AssetUploadException implements Exception {
  AssetUploadException(this.message);

  final String message;

  @override
  String toString() => 'AssetUploadException: $message';
}
