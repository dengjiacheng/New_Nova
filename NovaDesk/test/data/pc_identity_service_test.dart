import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/data/services/pc_identity_service.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

void main() {
  late Directory tempDir;
  late AppPaths appPaths;
  late PcIdentityServiceImpl service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nova_desk_identity_test_');
    appPaths = AppPaths(root: tempDir);
    final AppLogger logger = AppLogger(appPaths: appPaths);
    service = PcIdentityServiceImpl(appPaths: appPaths, clientVersion: '0.2.0', logger: logger);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PcIdentityServiceImpl', () {
    test('ensureLoaded creates new identity when file missing', () async {
      final identity = await service.ensureLoaded();

      expect(identity.pcId, startsWith('PC-'));
      expect(identity.clientVersion, '0.2.0');
      expect(await appPaths.pcConfigFile.exists(), isTrue);
    });

    test('ensureLoaded reuses existing identity', () async {
      final first = await service.ensureLoaded();
      final second = await service.ensureLoaded();
      expect(second.pcId, first.pcId);
    });

    test('updateLastLogin persists timestamp', () async {
      final first = await service.ensureLoaded();
      final DateTime newTimestamp = DateTime.now().toUtc();

      await service.updateLastLogin(newTimestamp);

      final reloaded = await service.ensureLoaded();
      expect(reloaded.lastLoginAt.difference(newTimestamp).abs(), lessThan(const Duration(milliseconds: 1)));
      expect(reloaded.pcId, first.pcId);
    });

    test('corrupted file will be backed up and regenerated', () async {
      final configFile = appPaths.pcConfigFile;
      await appPaths.ensureBaseDirectories();
      await configFile.writeAsString('{invalid-json');

      final identity = await service.ensureLoaded();

      expect(identity.pcId, startsWith('PC-'));
      final backupFiles = configFile.parent
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('pc.json.bak'));
      expect(backupFiles.length, 1);
    });
  });
}
