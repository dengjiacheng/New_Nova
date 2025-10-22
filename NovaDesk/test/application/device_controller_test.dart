import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/controllers/device_controller.dart';
import 'package:nova_desk/src/application/events/device_event_bus.dart';
import 'package:nova_desk/src/domain/entities/device_snapshot.dart';
import 'package:nova_desk/src/domain/events/device_event.dart';
import 'package:nova_desk/src/domain/ports/device_event_sink.dart';

void main() {
  group('DeviceController', () {
    test('updates state on device status event', () async {
      final DeviceEventSink bus = DeviceEventBus();
      final DeviceController controller = DeviceController(deviceEvents: bus);

      final DeviceSnapshot snapshot = DeviceSnapshot(
        deviceId: 'device-1',
        localStatus: DeviceLocalStatus.online,
        serverOnline: true,
        conflict: false,
        updatedAt: DateTime.now().toUtc(),
      );
      bus.publish(
        DeviceSyncCompleted(
          snapshots: <DeviceSnapshot>[snapshot],
          changed: <DeviceSnapshot>[snapshot],
          removedDeviceIds: const <String>[],
          syncedAt: DateTime.now().toUtc(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state.devices.length, 1);
      final device = controller.state.devices['device-1']!;
      expect(device.localStatus, DeviceLocalStatus.online);
      expect(device.serverOnline, isTrue);

      controller.dispose();
      await bus.dispose();
    });

    test('clears state when devices removed', () async {
      final DeviceEventSink bus = DeviceEventBus();
      final DeviceController controller = DeviceController(deviceEvents: bus);

      final DateTime now = DateTime.now().toUtc();
      bus.publish(
        DeviceSyncCompleted(
          snapshots: <DeviceSnapshot>[
            DeviceSnapshot(
              deviceId: 'device-1',
              localStatus: DeviceLocalStatus.online,
              serverOnline: true,
              conflict: false,
              updatedAt: now,
            ),
          ],
          changed: const <DeviceSnapshot>[],
          removedDeviceIds: const <String>[],
          syncedAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.devices, isNotEmpty);

      bus.publish(
        DeviceSyncCompleted(
          snapshots: const <DeviceSnapshot>[],
          changed: const <DeviceSnapshot>[],
          removedDeviceIds: const <String>['device-1'],
          syncedAt: DateTime.now().toUtc(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.devices, isEmpty);

      controller.dispose();
      await bus.dispose();
    });
  });
}
