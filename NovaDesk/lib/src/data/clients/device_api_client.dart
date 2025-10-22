import 'dart:async';

import 'dart:io';

import '../../platform/app_logger.dart';
import '../api/api_client.dart';
import 'package:dio/dio.dart';

class ServerDeviceInfo {
  const ServerDeviceInfo({
    required this.deviceId,
    required this.pcId,
    required this.online,
    this.alias,
    this.agentInfo,
  });

  final String deviceId;
  final String pcId;
  final bool online;
  final String? alias;
  final Map<String, dynamic>? agentInfo;
}

abstract class DeviceApiClient {
  Future<List<ServerDeviceInfo>> fetchOnlineDevices();
}

class NoopDeviceApiClient implements DeviceApiClient {
  NoopDeviceApiClient({AppLogger? logger}) : _logger = logger ?? AppLogger.defaultLogger();

  final AppLogger _logger;

  @override
  Future<List<ServerDeviceInfo>> fetchOnlineDevices() async {
    await _logger.warning('DeviceApiClient not configured, returning empty devices');
    return const <ServerDeviceInfo>[];
  }
}

class HttpDeviceApiClient implements DeviceApiClient {
  HttpDeviceApiClient({
    required ApiClient apiClient,
    AppLogger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? AppLogger.defaultLogger();

  final ApiClient _apiClient;
  final AppLogger _logger;

  @override
  Future<List<ServerDeviceInfo>> fetchOnlineDevices() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/api/devices');
      final List<dynamic> list = response.data?['devices'] as List<dynamic>? ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> json) => ServerDeviceInfo(
                deviceId: json['deviceId'] as String? ?? '',
                pcId: json['pcId'] as String? ?? '',
                online: (json['status'] as String? ?? '').toUpperCase() == 'ONLINE',
                alias: json['alias'] as String?,
                agentInfo: json,
              ))
          .toList();
    } on DioException catch (error) {
      await _logger.error('HTTP error when fetching devices', cause: error);
      return const <ServerDeviceInfo>[];
    } on SocketException catch (error) {
      await _logger.error('Network error when fetching devices', cause: error);
      return const <ServerDeviceInfo>[];
    }
  }
}
