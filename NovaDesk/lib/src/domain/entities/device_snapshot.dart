import 'dart:convert';

import 'package:meta/meta.dart';

@immutable
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.deviceId,
    required this.localStatus,
    required this.serverOnline,
    required this.conflict,
    required this.updatedAt,
    this.connectionType = DeviceConnectionType.unknown,
    this.wifiEndpoint,
    this.remoteOnly = false,
    this.adbProduct,
    this.adbModel,
    this.adbDeviceCode,
    this.androidVersion,
    this.screenResolution,
    this.alias,
    this.agentInfo,
    this.adbStatus,
    this.serverPcId,
  });

  final String deviceId;
  final DeviceLocalStatus localStatus;
  final bool serverOnline;
  final bool conflict;
  final DateTime updatedAt;
  final DeviceConnectionType connectionType;
  final String? wifiEndpoint;
  final bool remoteOnly;
  final String? adbProduct;
  final String? adbModel;
  final String? adbDeviceCode;
  final String? androidVersion;
  final String? screenResolution;
  final String? alias;
  final AgentInfoSnapshot? agentInfo;
  final String? adbStatus;
  final String? serverPcId;

  DeviceSnapshot copyWith({
    DeviceLocalStatus? localStatus,
    bool? serverOnline,
    bool? conflict,
    DateTime? updatedAt,
    DeviceConnectionType? connectionType,
    String? wifiEndpoint,
    bool? remoteOnly,
    String? adbProduct,
    String? adbModel,
    String? adbDeviceCode,
    String? androidVersion,
    String? screenResolution,
    String? alias,
    AgentInfoSnapshot? agentInfo,
    String? adbStatus,
    String? serverPcId,
  }) {
    return DeviceSnapshot(
      deviceId: deviceId,
      localStatus: localStatus ?? this.localStatus,
      serverOnline: serverOnline ?? this.serverOnline,
      conflict: conflict ?? this.conflict,
      updatedAt: updatedAt ?? this.updatedAt,
      connectionType: connectionType ?? this.connectionType,
      wifiEndpoint: wifiEndpoint ?? this.wifiEndpoint,
      remoteOnly: remoteOnly ?? this.remoteOnly,
      adbProduct: adbProduct ?? this.adbProduct,
      adbModel: adbModel ?? this.adbModel,
      adbDeviceCode: adbDeviceCode ?? this.adbDeviceCode,
      androidVersion: androidVersion ?? this.androidVersion,
      screenResolution: screenResolution ?? this.screenResolution,
      alias: alias ?? this.alias,
      agentInfo: agentInfo ?? this.agentInfo,
      adbStatus: adbStatus ?? this.adbStatus,
      serverPcId: serverPcId ?? this.serverPcId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'localStatus': localStatus.name,
      'serverOnline': serverOnline,
      'conflict': conflict,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'connectionType': connectionType.name,
      'wifiEndpoint': wifiEndpoint,
      'remoteOnly': remoteOnly,
      'adbProduct': adbProduct,
      'adbModel': adbModel,
      'adbDeviceCode': adbDeviceCode,
      'androidVersion': androidVersion,
      'screenResolution': screenResolution,
      'alias': alias,
      'agentInfo': agentInfo?.toJson(),
      'adbStatus': adbStatus,
      'serverPcId': serverPcId,
    };
  }

  static DeviceSnapshot fromJson(Map<String, dynamic> json) {
    final String deviceId = json['deviceId'] as String;
    final String statusRaw = json['localStatus'] as String? ?? 'offline';
    final DeviceLocalStatus localStatus =
        DeviceLocalStatus.values.firstWhere(
          (DeviceLocalStatus status) => status.name == statusRaw,
          orElse: () => DeviceLocalStatus.offline,
        );
    final String connectionRaw = json['connectionType'] as String? ?? 'unknown';
    final DeviceConnectionType connectionType = DeviceConnectionType.values.firstWhere(
      (DeviceConnectionType type) => type.name == connectionRaw,
      orElse: () => DeviceConnectionType.unknown,
    );
    return DeviceSnapshot(
      deviceId: deviceId,
      localStatus: localStatus,
      serverOnline: json['serverOnline'] as bool? ?? false,
      conflict: json['conflict'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      connectionType: connectionType,
      wifiEndpoint: json['wifiEndpoint'] as String?,
      remoteOnly: json['remoteOnly'] as bool? ?? false,
      adbProduct: json['adbProduct'] as String?,
      adbModel: json['adbModel'] as String?,
      adbDeviceCode: json['adbDeviceCode'] as String?,
      androidVersion: json['androidVersion'] as String?,
      screenResolution: json['screenResolution'] as String?,
      alias: json['alias'] as String?,
      agentInfo: (json['agentInfo'] as Map<String, dynamic>?)
          ?.let(AgentInfoSnapshot.fromJson),
      adbStatus: json['adbStatus'] as String?,
      serverPcId: json['serverPcId'] as String?,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

@immutable
class AgentInfoSnapshot {
  const AgentInfoSnapshot({
    required this.agentVersion,
    required this.scriptCatalog,
    required this.lastHeartbeat,
    this.currentExecution,
  });

  final String agentVersion;
  final List<String> scriptCatalog;
  final DateTime? lastHeartbeat;
  final Map<String, dynamic>? currentExecution;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'agentVersion': agentVersion,
        'scriptCatalog': scriptCatalog,
        'lastHeartbeat': lastHeartbeat?.toUtc().toIso8601String(),
        'currentExecution': currentExecution,
      };

  static AgentInfoSnapshot fromJson(Map<String, dynamic> json) {
    return AgentInfoSnapshot(
      agentVersion: json['agentVersion'] as String? ?? 'unknown',
      scriptCatalog: (json['scriptCatalog'] as List<dynamic>?)
              ?.map((dynamic item) => item.toString())
              .toList() ??
          const <String>[],
      lastHeartbeat: (json['lastHeartbeat'] as String?)
          ?.let(DateTime.parse)
          ?.toUtc(),
      currentExecution:
          json['currentExecution'] as Map<String, dynamic>?,
    );
  }
}

enum DeviceLocalStatus {
  offline,
  starting,
  online,
  stopping,
}

enum DeviceConnectionType {
  usb,
  wifi,
  unknown,
}

extension _NullableMapExt on Map<String, dynamic>? {
  T? let<T>(T Function(Map<String, dynamic> value) mapper) {
    final Map<String, dynamic>? value = this;
    if (value == null) {
      return null;
    }
    return mapper(value);
  }
}

extension _NullableStringExt on String? {
  T? let<T>(T Function(String value) mapper) {
    final String? value = this;
    if (value == null) {
      return null;
    }
    return mapper(value);
  }
}
