import '../../data/clients/device_api_client.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../platform/adb/adb_service.dart';

class DeviceMergeService {
  DeviceMergeService({required String pcId}) : _pcId = pcId;

  final String _pcId;

  List<DeviceSnapshot> merge({
    required List<AdbDeviceInfo> adbDevices,
    required List<ServerDeviceInfo> serverDevices,
    Map<String, DeviceSnapshot> current = const <String, DeviceSnapshot>{},
  }) {
    final Iterable<AdbDeviceInfo> usableAdbDevices = adbDevices.where(
      (AdbDeviceInfo device) => device.state.toLowerCase() != 'offline',
    );
    final Map<String, AdbDeviceInfo> adbById = {
      for (final AdbDeviceInfo device in usableAdbDevices) device.deviceId: device,
    };
    final Map<String, ServerDeviceInfo> serverById = {
      for (final ServerDeviceInfo device in serverDevices) device.deviceId: device,
    };
    final Set<String> allIds = <String>{
      ...adbById.keys,
      ...serverById.keys,
    };

    final List<DeviceSnapshot> results = <DeviceSnapshot>[];
    final DateTime now = DateTime.now().toUtc();
    for (final String deviceId in allIds) {
      final AdbDeviceInfo? adb = adbById[deviceId];
      final ServerDeviceInfo? server = serverById[deviceId];
       final DeviceSnapshot? previous = current[deviceId];
      final bool serverOnline = server?.online ?? false;
      final bool conflict = server != null && server.pcId != _pcId;

      final DeviceConnectionType connectionType = adb != null
          ? switch (adb.connectionType) {
              AdbConnectionType.wifi => DeviceConnectionType.wifi,
              AdbConnectionType.usb => DeviceConnectionType.usb,
              AdbConnectionType.unknown => DeviceConnectionType.unknown,
            }
          : DeviceConnectionType.unknown;

      final DeviceLocalStatus localStatus = _deriveLocalStatus(adb, previous);

      final bool remoteOnly = adb == null && serverOnline && !conflict;

      final DeviceSnapshot snapshot = DeviceSnapshot(
        deviceId: deviceId,
        localStatus: localStatus,
        serverOnline: serverOnline,
        conflict: conflict,
        connectionType: connectionType,
        wifiEndpoint: connectionType == DeviceConnectionType.wifi ? adb?.endpoint : null,
        remoteOnly: remoteOnly,
        adbProduct: adb?.properties['product'],
        adbModel: adb?.properties['model'],
        adbDeviceCode: adb?.properties['device'],
        androidVersion: adb?.androidVersion,
        screenResolution: adb?.screenResolution,
        alias: server?.alias ?? previous?.alias,
        agentInfo: server?.agentInfo != null
            ? AgentInfoSnapshot.fromJson(
                Map<String, dynamic>.from(server!.agentInfo!),
              )
            : previous?.agentInfo,
        adbStatus: adb?.state ?? previous?.adbStatus,
        serverPcId: server?.pcId ?? previous?.serverPcId,
        updatedAt: now,
      );

      results.add(snapshot);
    }

    results.sort((DeviceSnapshot a, DeviceSnapshot b) => a.deviceId.compareTo(b.deviceId));
    return results;
  }

  DeviceLocalStatus _deriveLocalStatus(
    AdbDeviceInfo? adb,
    DeviceSnapshot? previous,
  ) {
    final DeviceLocalStatus base = _mapLocalStatus(adb);
    if (previous == null) {
      return base;
    }
    if (previous.localStatus == DeviceLocalStatus.starting ||
        previous.localStatus == DeviceLocalStatus.stopping) {
      // 保留启动/停止中的过渡态，直到调度流程显式更新。
      return previous.localStatus;
    }
    return base;
  }

  DeviceLocalStatus _mapLocalStatus(AdbDeviceInfo? adb) {
    if (adb == null) {
      return DeviceLocalStatus.offline;
    }
    switch (adb.state.toLowerCase()) {
      case 'device':
        return DeviceLocalStatus.online;
      case 'sideload':
      case 'recovery':
      case 'offline':
      case 'unknown':
        return DeviceLocalStatus.offline;
      case 'unauthorized':
        return DeviceLocalStatus.offline;
      default:
        return DeviceLocalStatus.offline;
    }
  }
}
