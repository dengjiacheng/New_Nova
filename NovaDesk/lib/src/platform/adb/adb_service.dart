import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../platform/app_logger.dart';

/// ADB 设备信息。
class AdbDeviceInfo {
  AdbDeviceInfo({
    required this.deviceId,
    required this.state,
    required this.properties,
    this.connectionType = AdbConnectionType.unknown,
    this.endpoint,
    this.androidVersion,
    this.screenResolution,
  });

  final String deviceId;
  final String state;
  final Map<String, String> properties;
  final AdbConnectionType connectionType;
  final String? endpoint; // For Wi-Fi devices: ip:port
  final String? androidVersion;
  final String? screenResolution;

  AdbDeviceInfo copyWith({
    String? androidVersion,
    String? screenResolution,
  }) {
    return AdbDeviceInfo(
      deviceId: deviceId,
      state: state,
      properties: Map<String, String>.from(properties),
      connectionType: connectionType,
      endpoint: endpoint,
      androidVersion: androidVersion ?? this.androidVersion,
      screenResolution: screenResolution ?? this.screenResolution,
    );
  }
}

enum AdbConnectionType {
  usb,
  wifi,
  unknown,
}

/// 封装 ADB 操作的接口。
abstract class AdbService {
  Future<List<AdbDeviceInfo>> listDevices();
  Future<AdbCommandResult> connectWifiDevice(String hostPort);
  Future<AdbCommandResult> disconnectDevice(String serial);
  Future<AdbInstalledPackageInfo?> getInstalledPackageInfo(
    String deviceId,
    String packageName,
  );

  Future<String?> computeRemoteSha256(
    String deviceId,
    String remotePath,
  );

  Future<void> installApk(String deviceId, String apkPath);
}

class AdbInstalledPackageInfo {
  const AdbInstalledPackageInfo({
    required this.packageName,
    required this.versionCode,
    this.versionName,
    this.apkPath,
  });

  final String packageName;
  final int versionCode;
  final String? versionName;
  final String? apkPath;
}

class AdbCommandResult {
  const AdbCommandResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

class ProcessAdbService implements AdbService {
  ProcessAdbService({
    ProcessRunner? processRunner,
    AppLogger? logger,
  })  : _processRunner = processRunner ?? const ProcessRunner(),
        _logger = logger ?? AppLogger.defaultLogger();

  final ProcessRunner _processRunner;
  final AppLogger _logger;

  @override
  Future<List<AdbDeviceInfo>> listDevices() async {
    try {
      final ProcessResult result = await _processRunner.run(
        'adb',
        const <String>['devices', '-l'],
      );
      if (result.exitCode != 0) {
        throw AdbException(
          'adb devices failed with code ${result.exitCode}',
          stderr: result.stderr,
        );
      }
      final List<AdbDeviceInfo> parsed = _parseDevices(result.stdout as String);
      final List<AdbDeviceInfo> enriched = <AdbDeviceInfo>[];
      for (final AdbDeviceInfo info in parsed) {
        enriched.add(await _enrichDeviceInfo(info));
      }
      return enriched;
    } on ProcessException catch (error) {
      await _logger.error('Failed to execute adb devices', cause: error);
      rethrow;
    }
  }

  List<AdbDeviceInfo> _parseDevices(String stdout) {
    final List<AdbDeviceInfo> devices = <AdbDeviceInfo>[];
    final List<String> lines = const LineSplitter().convert(stdout);
    for (final String line in lines.skip(1)) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('*')) {
        continue;
      }
      final List<String> parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isEmpty) {
        continue;
      }
      final String deviceId = parts.first;
      final String state = parts.length >= 2 ? parts[1] : 'unknown';
      final Map<String, String> props = <String, String>{};
      for (final String part in parts.skip(2)) {
        final List<String> kv = part.split(':');
        if (kv.length == 2) {
          props[kv.first] = kv.last;
        }
      }
      final AdbConnectionType type =
          deviceId.contains(':') ? AdbConnectionType.wifi : AdbConnectionType.usb;
      final AdbDeviceInfo info = AdbDeviceInfo(
        deviceId: deviceId,
        state: state,
        properties: props,
        connectionType: type,
        endpoint: type == AdbConnectionType.wifi ? deviceId : null,
      );
      devices.add(info);
    }
    return devices;
  }

  Future<AdbDeviceInfo> _enrichDeviceInfo(AdbDeviceInfo info) async {
    if (info.state != 'device') {
      return info;
    }

    String? androidVersion = info.androidVersion;
    String? screenResolution = info.screenResolution;

    try {
      final ProcessResult versionResult = await _processRunner.run(
        'adb',
        <String>['-s', info.deviceId, 'shell', 'getprop', 'ro.build.version.release'],
      );
      if (versionResult.exitCode == 0) {
        final String value = (versionResult.stdout ?? '').toString().trim();
        if (value.isNotEmpty) {
          androidVersion = value.split(RegExp(r'[\r\n]')).first.trim();
        }
      }
    } catch (error) {
      await _logger.warning('Failed to query android version for ${info.deviceId}');
    }

    try {
      final ProcessResult sizeResult = await _processRunner.run(
        'adb',
        <String>['-s', info.deviceId, 'shell', 'wm', 'size'],
      );
      if (sizeResult.exitCode == 0) {
        final String output = (sizeResult.stdout ?? '').toString();
        final RegExpMatch? match =
            RegExp(r'Physical size:\s*(\d+)x(\d+)').firstMatch(output);
        if (match != null) {
          screenResolution = '${match.group(1)}x${match.group(2)}';
        }
      }
    } catch (error) {
      await _logger.warning('Failed to query screen size for ${info.deviceId}');
    }

    return info.copyWith(
      androidVersion: androidVersion,
      screenResolution: screenResolution,
    );
  }

  @override
  Future<AdbCommandResult> connectWifiDevice(String hostPort) async {
    try {
      final ProcessResult result = await _processRunner.run(
        'adb',
        <String>['connect', hostPort],
      );
      final AdbCommandResult output = AdbCommandResult(
        command: 'adb connect $hostPort',
        exitCode: result.exitCode,
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
      );
      if (!output.succeeded) {
        throw AdbException(
          'adb connect $hostPort failed with code ${result.exitCode}',
          stderr: result.stderr,
        );
      }
      await _logger.info(
          'adb connect success hostPort=$hostPort stdout=${output.stdout.trim()}');
      return output;
    } on ProcessException catch (error) {
      await _logger.error('Failed to execute adb connect $hostPort', cause: error);
      rethrow;
    }
  }

  @override
  Future<AdbCommandResult> disconnectDevice(String serial) async {
    try {
      final ProcessResult result = await _processRunner.run(
        'adb',
        <String>['disconnect', serial],
      );
      final AdbCommandResult output = AdbCommandResult(
        command: 'adb disconnect $serial',
        exitCode: result.exitCode,
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
      );
      if (!output.succeeded) {
        throw AdbException(
          'adb disconnect $serial failed with code ${result.exitCode}',
          stderr: result.stderr,
        );
      }
      await _logger.info(
          'adb disconnect success serial=$serial stdout=${output.stdout.trim()}');
      return output;
    } on ProcessException catch (error) {
      await _logger.error('Failed to execute adb disconnect $serial', cause: error);
      rethrow;
    }
  }

  @override
  Future<AdbInstalledPackageInfo?> getInstalledPackageInfo(
    String deviceId,
    String packageName,
  ) async {
    try {
      final ProcessResult pathResult = await _processRunner.run(
        'adb',
        <String>['-s', deviceId, 'shell', 'pm', 'path', packageName],
      );
      if (pathResult.exitCode != 0) {
        return null;
      }
      final String stdout = (pathResult.stdout ?? '').toString();
      final List<String> lines = stdout
          .split(RegExp(r'\s+'))
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        return null;
      }
      String? apkPath;
      for (final String line in lines) {
        if (line.startsWith('package:')) {
          apkPath = line.substring('package:'.length);
          break;
        }
      }

      final ProcessResult dumpResult = await _processRunner.run(
        'adb',
        <String>['-s', deviceId, 'shell', 'dumpsys', 'package', packageName],
      );
      if (dumpResult.exitCode != 0) {
        return null;
      }
      final String dump = (dumpResult.stdout ?? '').toString();
      final RegExp versionCodePattern = RegExp(r'versionCode=(\d+)');
      final RegExp versionNamePattern = RegExp(r'versionName=([^\s]+)');
      final Match? versionCodeMatch = versionCodePattern.firstMatch(dump);
      if (versionCodeMatch == null) {
        return null;
      }
      final int versionCode = int.tryParse(versionCodeMatch.group(1) ?? '') ?? 0;
      final String? versionName = versionNamePattern.firstMatch(dump)?.group(1);

      return AdbInstalledPackageInfo(
        packageName: packageName,
        versionCode: versionCode,
        versionName: versionName,
        apkPath: apkPath,
      );
    } on ProcessException catch (error) {
      await _logger.error('Failed to query package info $packageName on $deviceId', cause: error);
      return null;
    }
  }

  @override
  Future<String?> computeRemoteSha256(String deviceId, String remotePath) async {
    Future<String?> runCommand(List<String> args) async {
      try {
        final ProcessResult result = await _processRunner.run('adb', args);
        if (result.exitCode != 0) {
          return null;
        }
        final String output = (result.stdout ?? '').toString().trim();
        if (output.isEmpty) {
          return null;
        }
        return output.split(RegExp(r'\s+')).first;
      } on ProcessException {
        return null;
      }
    }

    String? hash = await runCommand(<String>['-s', deviceId, 'shell', 'sha256sum', remotePath]);
    hash ??= await runCommand(<String>['-s', deviceId, 'exec-out', 'sha256sum', remotePath]);
    if (hash != null) {
      return hash;
    }

    final Directory tempDir = await Directory.systemTemp.createTemp('nova_agent_pull_');
    try {
      final String localPath = p.join(tempDir.path, 'apk.tmp');
      final ProcessResult pullResult = await _processRunner.run(
        'adb',
        <String>['-s', deviceId, 'pull', remotePath, localPath],
      );
      if (pullResult.exitCode != 0) {
        return null;
      }
      final File localFile = File(localPath);
      final crypto.Digest digest = await crypto.sha256.bind(localFile.openRead()).first;
      return digest.toString();
    } on ProcessException {
      return null;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) {});
    }
  }

  @override
  Future<void> installApk(String deviceId, String apkPath) async {
    try {
      final ProcessResult result = await _processRunner.run(
        'adb',
        <String>['-s', deviceId, 'install', '-r', apkPath],
      );
      if (result.exitCode != 0) {
        throw AdbException(
          'adb install failed with code ${result.exitCode}',
          stderr: result.stderr,
        );
      }
      await _logger.info('Installed APK on $deviceId from $apkPath');
    } on ProcessException catch (error) {
      await _logger.error('Failed to execute adb install $apkPath on $deviceId', cause: error);
      rethrow;
    }
  }
}

class AdbException implements Exception {
  AdbException(this.message, {this.stderr});

  final String message;
  final Object? stderr;

  @override
  String toString() => 'AdbException: $message stderr=$stderr';
}

/// 可替换的进程执行器，方便测试注入。
class ProcessRunner {
  const ProcessRunner();

  Future<ProcessResult> run(String executable, List<String> arguments) {
    return Process.run(executable, arguments);
  }
}
