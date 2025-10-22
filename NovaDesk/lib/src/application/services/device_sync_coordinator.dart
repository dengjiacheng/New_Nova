import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/clients/device_api_client.dart';
import '../../data/repositories/device_repository.dart';
import '../../domain/entities/device_snapshot.dart';
import '../../domain/events/device_event.dart';
import '../../domain/ports/device_event_sink.dart';
import '../../platform/adb/adb_service.dart';
import '../../platform/app_logger.dart';
import 'device_merge_service.dart';

class DeviceSyncCoordinator {
  DeviceSyncCoordinator({
    required AdbService adbService,
    required DeviceApiClient deviceApiClient,
    required DeviceMergeService mergeService,
    required DeviceEventSink deviceEvents,
    DeviceRepository? deviceRepository,
    AppLogger? logger,
    Duration interval = const Duration(seconds: 5),
  })  : _adbService = adbService,
        _deviceApiClient = deviceApiClient,
        _mergeService = mergeService,
        _deviceEvents = deviceEvents,
        _deviceRepository = deviceRepository,
        _logger = logger ?? AppLogger.defaultLogger(),
        _interval = interval;

  final AdbService _adbService;
  final DeviceApiClient _deviceApiClient;
  final DeviceMergeService _mergeService;
  final DeviceEventSink _deviceEvents;
  final DeviceRepository? _deviceRepository;
  final AppLogger _logger;
  final Duration _interval;

  Timer? _timer;
  bool _started = false;
  bool _initialStateLoaded = false;
  final Map<String, DeviceSnapshot> _currentSnapshots =
      <String, DeviceSnapshot>{};

  Future<void> start() async {
    if (_started) {
      return;
    }
    await _ensureInitialStateLoaded();
    _started = true;
    await syncOnce();
    _timer = Timer.periodic(_interval, (_) {
      unawaited(syncOnce());
    });
  }

  Future<void> syncOnce() async {
    await _ensureInitialStateLoaded();
    List<AdbDeviceInfo>? adbDevices;
    try {
      adbDevices = await _adbService.listDevices();
    } catch (error) {
      await _logger.warning('ADB listDevices failed, use server result only');
    }

    List<ServerDeviceInfo>? serverDevices;
    try {
      serverDevices = await _deviceApiClient.fetchOnlineDevices();
    } catch (error) {
      await _logger.error('Fetch server devices failed', cause: error);
    }

    if (adbDevices == null && serverDevices == null) {
      return;
    }

    final List<DeviceSnapshot> merged = _mergeService.merge(
      adbDevices: adbDevices ?? const <AdbDeviceInfo>[],
      serverDevices: serverDevices ?? const <ServerDeviceInfo>[],
      current: Map<String, DeviceSnapshot>.unmodifiable(_currentSnapshots),
    );

    await _handleMergedSnapshots(merged);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<AdbCommandResult> connectWifiDevice(String hostPort) async {
    final AdbCommandResult result = await _adbService.connectWifiDevice(hostPort);
    await syncOnce();
    return result;
  }

  Future<AdbCommandResult> disconnectDevice(String serial) async {
    final AdbCommandResult result = await _adbService.disconnectDevice(serial);
    await syncOnce();
    return result;
  }

  Future<void> _ensureInitialStateLoaded() async {
    if (_initialStateLoaded) {
      return;
    }
    final DeviceRepository? repository = _deviceRepository;
    if (repository != null) {
      await repository.load();
      final List<DeviceSnapshot> cached = repository.getAll();
      _currentSnapshots
        ..clear()
        ..addEntries(
          cached.map(
            (DeviceSnapshot snapshot) =>
                MapEntry<String, DeviceSnapshot>(snapshot.deviceId, snapshot),
          ),
        );
    }
    _initialStateLoaded = true;
  }

  Future<void> _handleMergedSnapshots(List<DeviceSnapshot> merged) async {
    final Map<String, DeviceSnapshot> previousSnapshots =
        Map<String, DeviceSnapshot>.from(_currentSnapshots);
    final Set<String> mergedIds = merged.map((DeviceSnapshot snapshot) => snapshot.deviceId).toSet();
    final List<String> removedDeviceIds = previousSnapshots.keys
        .where((String id) => !mergedIds.contains(id))
        .toList(growable: false);
    List<DeviceSnapshot> changed = <DeviceSnapshot>[];

    final DeviceRepository? repository = _deviceRepository;
    if (repository != null) {
      for (final String deviceId in removedDeviceIds) {
        await repository.delete(deviceId);
      }
      final Iterable<DeviceSnapshot> persistedChanges = await repository.upsertAll(merged);
      changed = List<DeviceSnapshot>.from(persistedChanges);
      final List<DeviceSnapshot> persisted = repository.getAll();
      _currentSnapshots
        ..clear()
        ..addEntries(
          persisted.map(
            (DeviceSnapshot snapshot) =>
                MapEntry<String, DeviceSnapshot>(snapshot.deviceId, snapshot),
          ),
        );
    } else {
      final List<DeviceSnapshot> localChanges = <DeviceSnapshot>[];
      for (final DeviceSnapshot snapshot in merged) {
        final DeviceSnapshot? existing = _currentSnapshots[snapshot.deviceId];
        if (existing == null || !_areSnapshotsEqual(existing, snapshot)) {
          localChanges.add(snapshot);
        }
      }
      changed = localChanges;
      _currentSnapshots
        ..clear()
        ..addEntries(
          merged.map(
            (DeviceSnapshot snapshot) =>
                MapEntry<String, DeviceSnapshot>(snapshot.deviceId, snapshot),
          ),
        );
    }

    final DateTime syncedAt = DateTime.now().toUtc();
    final List<DeviceSnapshot> latestSnapshots =
        List<DeviceSnapshot>.unmodifiable(_currentSnapshots.values.toList()
          ..sort((DeviceSnapshot a, DeviceSnapshot b) => a.deviceId.compareTo(b.deviceId)));
    _deviceEvents.publish(
      DeviceSyncCompleted(
        snapshots: latestSnapshots,
        changed: List<DeviceSnapshot>.unmodifiable(changed),
        removedDeviceIds: List<String>.unmodifiable(removedDeviceIds),
        syncedAt: syncedAt,
      ),
    );
    await _logger.info(
      'Device sync produced ${merged.length} records, removed ${removedDeviceIds.length}',
    );
  }

  bool _areSnapshotsEqual(DeviceSnapshot a, DeviceSnapshot b) {
    return mapEquals(a.toJson(), b.toJson());
  }
}
