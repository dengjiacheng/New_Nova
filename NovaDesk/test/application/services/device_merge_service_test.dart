import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/services/device_merge_service.dart';
import 'package:nova_desk/src/data/clients/device_api_client.dart';
import 'package:nova_desk/src/domain/entities/device_snapshot.dart';
import 'package:nova_desk/src/platform/adb/adb_service.dart';

void main() {
  group('DeviceMergeService', () {
    test('marks local device online when detected locally', () {
      final DeviceMergeService service = DeviceMergeService(pcId: 'PC-1');
      final List<DeviceSnapshot> result = service.merge(
        adbDevices: <AdbDeviceInfo>[
          AdbDeviceInfo(deviceId: 'emulator-5554', state: 'device', properties: const {}),
        ],
        serverDevices: const <ServerDeviceInfo>[],
        current: const <String, DeviceSnapshot>{},
      );

      expect(result.length, 1);
      final DeviceSnapshot snapshot = result.first;
      expect(snapshot.deviceId, 'emulator-5554');
      expect(snapshot.localStatus, DeviceLocalStatus.online);
      expect(snapshot.serverOnline, isFalse);
      expect(snapshot.conflict, isFalse);
    });

    test('flags conflict when server pcId mismatched', () {
      final DeviceMergeService service = DeviceMergeService(pcId: 'PC-1');
      final List<DeviceSnapshot> result = service.merge(
        adbDevices: const <AdbDeviceInfo>[],
        serverDevices: const <ServerDeviceInfo>[
          ServerDeviceInfo(
            deviceId: 'device-1',
            pcId: 'PC-OTHER',
            online: true,
            alias: 'Agent',
          ),
        ],
        current: const <String, DeviceSnapshot>{},
      );

      final DeviceSnapshot snapshot = result.first;
      expect(snapshot.serverOnline, isTrue);
      expect(snapshot.conflict, isTrue);
      expect(snapshot.localStatus, DeviceLocalStatus.offline);
    });

    test('preserves transient local status', () {
      final DeviceMergeService service = DeviceMergeService(pcId: 'PC-1');
      final DeviceSnapshot existing = DeviceSnapshot(
        deviceId: 'device-1',
        localStatus: DeviceLocalStatus.starting,
        serverOnline: false,
        conflict: false,
        updatedAt: DateTime.now().toUtc(),
      );
      final List<DeviceSnapshot> result = service.merge(
        adbDevices: <AdbDeviceInfo>[
          AdbDeviceInfo(deviceId: 'device-1', state: 'device', properties: const {}),
        ],
        serverDevices: const <ServerDeviceInfo>[],
        current: <String, DeviceSnapshot>{'device-1': existing},
      );

      expect(result.first.localStatus, DeviceLocalStatus.starting);
    });

    test('filters adb entries reported as offline', () {
      final DeviceMergeService service = DeviceMergeService(pcId: 'PC-1');
      final List<DeviceSnapshot> result = service.merge(
        adbDevices: <AdbDeviceInfo>[
          AdbDeviceInfo(deviceId: '192.168.0.105:5555', state: 'offline', properties: const {}),
        ],
        serverDevices: const <ServerDeviceInfo>[],
        current: const <String, DeviceSnapshot>{},
      );

      expect(result, isEmpty);
    });
  });
}
