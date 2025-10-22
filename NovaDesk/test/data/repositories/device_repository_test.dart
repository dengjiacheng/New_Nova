import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/data/repositories/device_repository.dart';
import 'package:nova_desk/src/domain/entities/device_snapshot.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

class _InMemoryLogger extends AppLogger {
  _InMemoryLogger() : super(appPaths: AppPaths(root: Directory.systemTemp));

  final List<String> lines = <String>[];

  @override
  Future<void> info(String message) async => lines.add('[INFO] $message');

  @override
  Future<void> warning(String message) async => lines.add('[WARN] $message');

  @override
  Future<void> error(String message, {Object? cause}) async =>
      lines.add('[ERR] $message cause=$cause');
}

void main() {
  late Directory tempDir;
  late DeviceRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('device_repo_test_');
    repository = DeviceRepository(
      appPaths: AppPaths(root: tempDir),
      logger: _InMemoryLogger(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('upsertAll persists snapshots and detects changes', () async {
    final DeviceSnapshot snapshot = DeviceSnapshot(
      deviceId: 'device-1',
      localStatus: DeviceLocalStatus.online,
      serverOnline: true,
      conflict: false,
      updatedAt: DateTime.now().toUtc(),
    );

    final List<DeviceSnapshot> changed = await repository.upsertAll(<DeviceSnapshot>[snapshot]);
    expect(changed.length, 1);

    final List<DeviceSnapshot> changedAgain = await repository.upsertAll(<DeviceSnapshot>[snapshot]);
    expect(changedAgain, isEmpty);

    final File cacheFile = File('${tempDir.path}/cache/devices.json');
    expect(await cacheFile.exists(), isTrue);
  });
}
