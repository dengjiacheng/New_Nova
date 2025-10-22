import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '../../domain/entities/device_snapshot.dart';
import '../../platform/app_logger.dart';
import '../../platform/app_paths.dart';

class DeviceRepository {
  DeviceRepository({
    AppPaths? appPaths,
    AppLogger? logger,
  })  : _appPaths = appPaths ?? AppPaths(),
        _logger = logger ?? AppLogger.defaultLogger();

  final AppPaths _appPaths;
  final AppLogger _logger;
  final Map<String, DeviceSnapshot> _devices = <String, DeviceSnapshot>{};
  bool _loaded = false;
  final DeepCollectionEquality _deepEquality = const DeepCollectionEquality();

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    await _appPaths.ensureBaseDirectories();
    final File cacheFile = _cacheFile;
    if (!await cacheFile.exists()) {
      _loaded = true;
      return;
    }
    try {
      final String content = await cacheFile.readAsString();
      if (content.isEmpty) {
        _loaded = true;
        return;
      }
      final Map<String, dynamic> json =
          jsonDecode(content) as Map<String, dynamic>;
      final List<dynamic> items = json['devices'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic entry in items) {
        if (entry is Map<String, dynamic>) {
          final DeviceSnapshot snapshot = DeviceSnapshot.fromJson(entry);
          _devices[snapshot.deviceId] = snapshot;
        }
      }
      _loaded = true;
    } catch (error) {
      await _logger.error('Failed to load device cache', cause: error);
      _loaded = true;
    }
  }

  List<DeviceSnapshot> getAll() => List<DeviceSnapshot>.unmodifiable(_devices.values);

  DeviceSnapshot? getById(String deviceId) => _devices[deviceId];

  Future<List<DeviceSnapshot>> upsertAll(Iterable<DeviceSnapshot> snapshots) async {
    await load();
    final List<DeviceSnapshot> changed = <DeviceSnapshot>[];
    final Map<String, DeviceSnapshot> next = Map<String, DeviceSnapshot>.from(_devices);

    for (final DeviceSnapshot snapshot in snapshots) {
      final DeviceSnapshot? existing = next[snapshot.deviceId];
      if (existing == null || !_equals(existing, snapshot)) {
        next[snapshot.deviceId] = snapshot;
        changed.add(snapshot);
      }
    }

    _devices
      ..clear()
      ..addAll(next);

    await _persist();
    return changed;
  }

  Future<void> delete(String deviceId) async {
    await load();
    if (_devices.remove(deviceId) != null) {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final File cacheFile = _cacheFile;
    final Map<String, dynamic> payload = <String, dynamic>{
      'devices': _devices.values.map((DeviceSnapshot snapshot) => snapshot.toJson()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  bool _equals(DeviceSnapshot a, DeviceSnapshot b) {
    return _deepEquality.equals(a.toJson(), b.toJson());
  }

  File get _cacheFile => File('${_appPaths.cacheDir.path}/devices.json');
}
