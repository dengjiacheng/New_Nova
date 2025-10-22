import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../data/api/api_client.dart';
import '../../data/clients/admin_package_api_client.dart';
import '../../domain/entities/agent_package.dart';
import '../../platform/adb/adb_service.dart';
import '../../platform/app_logger.dart';
import '../../platform/app_paths.dart';

class AgentPackagePreparationResult {
  const AgentPackagePreparationResult({
    required this.status,
    required this.message,
  });

  final AgentPreparationStatus status;
  final String message;
}

enum AgentPreparationStatus {
  upToDate,
  installed,
}

class AgentPackageManager {
  AgentPackageManager({
    required AdminPackageApiClient adminClient,
    required ApiClient apiClient,
    required AdbService adbService,
    AppPaths? appPaths,
    AppLogger? logger,
  })  : _adminClient = adminClient,
        _dio = apiClient.dio,
        _adbService = adbService,
        _appPaths = appPaths ?? AppPaths(),
        _logger = logger ?? AppLogger.defaultLogger();

  final AdminPackageApiClient _adminClient;
  final Dio _dio;
  final AdbService _adbService;
  final AppPaths _appPaths;
  final AppLogger _logger;

  static const String _agentPackageName = 'com.nova.agent';
  LatestPackage? _cachedPackage;

  Future<AgentPackagePreparationResult> prepareDevice(String deviceId) async {
    final LatestPackage artifact = await _ensureLatestPackage();
    final AdbInstalledPackageInfo? installed =
        await _adbService.getInstalledPackageInfo(deviceId, _agentPackageName);

    if (installed != null &&
        installed.versionCode == artifact.metadata.versionCode &&
        installed.apkPath != null) {
      final String? remoteHash =
          await _adbService.computeRemoteSha256(deviceId, installed.apkPath!);
      if (remoteHash != null) {
        if (_normalize(remoteHash) == artifact.checksum) {
          await _logger.info(
              'Device $deviceId already up-to-date (package ${artifact.metadata.packageId})');
          return const AgentPackagePreparationResult(
            status: AgentPreparationStatus.upToDate,
            message: '设备已安装最新 Agent 版本',
          );
        }
      } else {
        await _logger.warning(
            'Unable to compute remote checksum for $deviceId, reinstalling agent');
      }
    }

    await _adbService.installApk(deviceId, artifact.file.path);
    await _logger.info(
        'Installed latest agent package ${artifact.metadata.packageId} on $deviceId');

    final AdbInstalledPackageInfo? postInstall =
        await _adbService.getInstalledPackageInfo(deviceId, _agentPackageName);
    if (postInstall?.apkPath != null) {
      final String? verifyHash =
          await _adbService.computeRemoteSha256(deviceId, postInstall!.apkPath!);
      if (verifyHash != null && _normalize(verifyHash) != artifact.checksum) {
        throw StateError('安装后校验失败，请重试');
      }
    }

    return AgentPackagePreparationResult(
      status: AgentPreparationStatus.installed,
      message: '已安装最新 Agent 包 ${artifact.metadata.versionName}',
    );
  }

  Future<LatestPackage> _ensureLatestPackage() async {
    final AgentPackage? latest = await _adminClient.fetchLatest();
    if (latest == null) {
      throw StateError('服务器未发布 Agent 包，请先在 Admin Tools 上传并激活');
    }
    final String? downloadUrl = latest.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw StateError('服务器返回的 Agent 包缺少下载链接');
    }

    final LatestPackage? cached = _cachedPackage;
    if (cached != null && cached.metadata.packageId == latest.packageId) {
      return cached;
    }

    final Directory cacheDir =
        Directory(p.join(_appPaths.cacheDir.path, 'agent_packages'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final File targetFile = File(p.join(cacheDir.path, '${latest.packageId}.apk'));
    final String expectedChecksum = _normalize(latest.checksum);

    if (targetFile.existsSync()) {
      final String localHash = await _computeLocalSha256(targetFile);
      if (localHash != expectedChecksum) {
        await _logger.warning(
            'Cached APK checksum mismatch (expected=$expectedChecksum, actual=$localHash)，重新下载');
        targetFile.deleteSync();
      }
    }

    if (!targetFile.existsSync()) {
      await _download(downloadUrl, targetFile);
      final String downloadedHash = await _computeLocalSha256(targetFile);
      if (downloadedHash != expectedChecksum) {
        targetFile.deleteSync();
        throw StateError('下载的 Agent 包校验失败，请稍后重试');
      }
    }

    final LatestPackage prepared = LatestPackage(
      metadata: latest,
      file: targetFile,
      checksum: expectedChecksum,
    );
    _cachedPackage = prepared;
    return prepared;
  }

  Future<void> _download(String url, File file) async {
    await _logger.info('Downloading agent package from $url');
    final Uri resolved = Uri.parse(_dio.options.baseUrl).resolve(url);
    await _dio.downloadUri(
      resolved,
      file.path,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<String> _computeLocalSha256(File file) async {
    final crypto.Digest digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _normalize(String? checksum) {
    if (checksum == null) {
      return '';
    }
    final String lower = checksum.toLowerCase();
    return lower.startsWith('sha256:') ? lower.substring(7) : lower;
  }
}

class LatestPackage {
  const LatestPackage({
    required this.metadata,
    required this.file,
    required this.checksum,
  });

  final AgentPackage metadata;
  final File file;
  final String checksum;
}
