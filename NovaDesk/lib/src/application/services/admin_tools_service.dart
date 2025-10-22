import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;

import '../../data/clients/admin_package_api_client.dart';
import '../../domain/entities/agent_package.dart';
import '../../platform/app_logger.dart';

class AdminToolsException implements Exception {
  const AdminToolsException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AdminToolsService {
  AdminToolsService({
    required AdminPackageApiClient apiClient,
    required AppLogger logger,
  })  : _apiClient = apiClient,
        _logger = logger;

  final AdminPackageApiClient _apiClient;
  final AppLogger _logger;

  Future<List<AgentPackage>> fetchPackages() async {
    try {
      final List<AgentPackage> packages = await _apiClient.listPackages();
      await _logger.info('Fetched ${packages.length} agent packages');
      return packages;
    } on dio.DioException catch (error) {
      final AdminToolsException wrapped = _wrapDioError(
        error,
        defaultMessage: '获取 Agent 包列表失败',
      );
      await _logger.error('Failed to fetch agent packages', cause: wrapped);
      throw wrapped;
    }
  }

  Future<AgentPackage> uploadPackage({
    required File file,
    required String versionName,
    required int versionCode,
    String? releaseNotes,
    String? checksum,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      await _logger.info(
        'Uploading Agent package version=$versionName($versionCode) size=${file.lengthSync()} checksum=$checksum',
      );
      final AgentPackage result = await _apiClient.uploadPackage(
        file: file,
        versionName: versionName,
        versionCode: versionCode,
        releaseNotes: releaseNotes,
        checksum: checksum,
        onSendProgress: onSendProgress,
      );
      await _logger.info('Upload completed packageId=${result.packageId}');
      return result;
    } on dio.DioException catch (error) {
      final AdminToolsException wrapped = _wrapDioError(
        error,
        defaultMessage: '上传 Agent 包失败',
      );
      await _logger.error('Upload agent package failed', cause: wrapped);
      throw wrapped;
    }
  }

  Future<void> activatePackage({required String packageId, String? notes}) async {
    try {
      await _logger.info('Activating Agent package $packageId notes=$notes');
      await _apiClient.activatePackage(packageId, notes: notes);
    } on dio.DioException catch (error) {
      final AdminToolsException wrapped = _wrapDioError(
        error,
        defaultMessage: '设置激活版本失败',
      );
      await _logger.error('Failed to activate agent package', cause: wrapped);
      throw wrapped;
    }
  }

  Future<void> deletePackage(String packageId) async {
    try {
      await _logger.info('Deleting Agent package $packageId');
      await _apiClient.deletePackage(packageId);
    } on dio.DioException catch (error) {
      final AdminToolsException wrapped = _wrapDioError(
        error,
        defaultMessage: '删除 Agent 包失败',
      );
      await _logger.error('Delete agent package failed', cause: wrapped);
      throw wrapped;
    }
  }

  Future<String> computeSha256(File file) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    final String checksum = 'sha256:${digest.toString()}';
    await _logger.info('Computed checksum for ${file.path} => $checksum');
    return checksum;
  }

  Future<AgentPackage?> fetchLatest() => _apiClient.fetchLatest();

  AdminToolsException _wrapDioError(
    dio.DioException error, {
    required String defaultMessage,
  }) {
    String? code;
    String message = error.message ?? defaultMessage;

    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final Map<String, dynamic> payload = data;
      code = payload['code']?.toString();
      final String? serverMessage = payload['message']?.toString();
      if (serverMessage != null && serverMessage.isNotEmpty) {
        message = serverMessage;
      }
      if (payload['data'] is Map<String, dynamic>) {
        final Map<String, dynamic> nested = payload['data'] as Map<String, dynamic>;
        if (nested['message'] is String && (nested['message'] as String).isNotEmpty) {
          message = nested['message'] as String;
        }
      }
    }

    if (code == 'CHECKSUM_MISMATCH') {
      message = '校验值不匹配，服务器已拒绝该文件，请确认 APK 是否被篡改';
    } else if (code == null || code.isEmpty) {
      code = error.response?.statusCode?.toString();
    }

    final String friendly =
        message.isNotEmpty ? message : '$defaultMessage（网络异常）';
    return AdminToolsException(
      friendly,
      code: code,
    );
  }
}
