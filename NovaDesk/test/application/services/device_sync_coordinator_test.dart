import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/services/device_merge_service.dart';
import 'package:nova_desk/src/application/services/device_sync_coordinator.dart';
import 'package:nova_desk/src/data/clients/device_api_client.dart';
import 'package:nova_desk/src/data/repositories/device_repository.dart';
import 'package:nova_desk/src/domain/entities/device_snapshot.dart';
import 'package:nova_desk/src/domain/events/device_event.dart';
import 'package:nova_desk/src/domain/ports/device_event_sink.dart';
import 'package:nova_desk/src/platform/adb/adb_service.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';
import 'package:nova_desk/src/application/events/device_event_bus.dart';

class _FakeAdbService implements AdbService {
  _FakeAdbService(this.devices);

  List<AdbDeviceInfo> devices;

  @override
  Future<List<AdbDeviceInfo>> listDevices() async => devices;

  @override
  Future<AdbCommandResult> connectWifiDevice(String hostPort) async {
    return AdbCommandResult(
      command: 'adb connect $hostPort',
      exitCode: 0,
      stdout: 'connected to $hostPort',
      stderr: '',
    );
  }

  @override
  Future<AdbCommandResult> disconnectDevice(String serial) async {
    return AdbCommandResult(
      command: 'adb disconnect $serial',
      exitCode: 0,
      stdout: 'disconnected $serial',
      stderr: '',
    );
  }
}

class _FakeDeviceApiClient implements DeviceApiClient {
  _FakeDeviceApiClient(this.devices);

  List<ServerDeviceInfo> devices;

  @override
  Future<List<ServerDeviceInfo>> fetchOnlineDevices() async => devices;
}

class _SilentLogger extends AppLogger {
  _SilentLogger(AppPaths paths) : super(appPaths: paths);

  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {Object? cause}) async {}
}

void main() {
  late Directory tempDir;
  late AppPaths appPaths;
  late DeviceEventSink bus;
  late _FakeAdbService adb;
  late _FakeDeviceApiClient apiClient;
  late DeviceRepository repository;
  late DeviceSyncCoordinator coordinator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('device_sync_test_');
    appPaths = AppPaths(root: tempDir);
    bus = DeviceEventBus();
    adb = _FakeAdbService(<AdbDeviceInfo>[
      AdbDeviceInfo(deviceId: 'device-1', state: 'device', properties: const {}),
    ]);
    apiClient = _FakeDeviceApiClient(<ServerDeviceInfo>[
      const ServerDeviceInfo(deviceId: 'device-1', pcId: 'PC-1', online: true),
    ]);
    repository = DeviceRepository(appPaths: appPaths, logger: _SilentLogger(appPaths));
    coordinator = DeviceSyncCoordinator(
      adbService: adb,
      deviceApiClient: apiClient,
      deviceRepository: repository,
      mergeService: DeviceMergeService(pcId: 'PC-1'),
      deviceEvents: bus,
      logger: _SilentLogger(appPaths),
      interval: const Duration(days: 1),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await bus.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('initial sync publishes device state', () async {
    final Future<DeviceSyncCompleted> future = bus.stream
        .where((DeviceEvent event) => event is DeviceSyncCompleted)
        .cast<DeviceSyncCompleted>()
        .first;

    await coordinator.start();

    final DeviceSyncCompleted event = await future;
    expect(event.snapshots, hasLength(1));
    final DeviceSnapshot snapshot = event.snapshots.first;
    expect(snapshot.deviceId, 'device-1');
    expect(snapshot.serverOnline, isTrue);
    expect(snapshot.localStatus, DeviceLocalStatus.online);
    expect(event.removedDeviceIds, isEmpty);
  });

  test('server push updates repository and publishes event', () async {
    await coordinator.start();

    apiClient.devices = <ServerDeviceInfo>[
      const ServerDeviceInfo(deviceId: 'device-1', pcId: 'PC-1', online: false),
    ];

    await coordinator.syncOnce();
    final DeviceSnapshot? snapshot = repository.getById('device-1');
    expect(snapshot, isNotNull);
    expect(snapshot!.serverOnline, isFalse);
    expect(snapshot.localStatus, DeviceLocalStatus.offline);
  });

  test('removes device when absent in adb and server', () async {
    await coordinator.start();

    adb.devices = <AdbDeviceInfo>[
      AdbDeviceInfo(deviceId: 'device-1', state: 'offline', properties: const {}),
    ];
    apiClient.devices = <ServerDeviceInfo>[];

    final Future<DeviceSyncCompleted> removalFuture = bus.stream
        .where((DeviceEvent event) => event is DeviceSyncCompleted)
        .cast<DeviceSyncCompleted>()
        .firstWhere((DeviceSyncCompleted event) => event.snapshots.isEmpty);

    await coordinator.syncOnce();

    final DeviceSyncCompleted removal = await removalFuture;
    expect(removal.snapshots, isEmpty);
    expect(removal.removedDeviceIds, contains('device-1'));
    expect(repository.getAll(), isEmpty);
  });
}
