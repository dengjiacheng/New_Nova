import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';
import 'package:nova_desk/src/platform/single_instance_guard.dart';

void main() {
  late Directory tempDir;
  late AppPaths appPaths;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nova_desk_guard_test_');
    appPaths = AppPaths(root: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SingleInstanceGuardImpl', () {
    test('acquire creates lock file and prevents second acquisition', () async {
      final AppLogger logger = AppLogger(appPaths: appPaths);
      final SingleInstanceGuardImpl guard = SingleInstanceGuardImpl(appPaths: appPaths, logger: logger);

      final SingleInstanceGuardHandle handle = await guard.acquire();
      expect(await appPaths.lockFile.exists(), isTrue);

      final SingleInstanceGuardImpl anotherGuard =
          SingleInstanceGuardImpl(appPaths: appPaths, logger: logger);
      expect(
        () => anotherGuard.acquire(),
        throwsA(isA<SingleInstanceAlreadyRunningException>()),
      );

      await handle.release();
      expect(await appPaths.lockFile.exists(), isFalse);
    });

    test('acquire twice with same instance reuses handle', () async {
      final AppLogger logger = AppLogger(appPaths: appPaths);
      final SingleInstanceGuardImpl guard = SingleInstanceGuardImpl(appPaths: appPaths, logger: logger);

      final SingleInstanceGuardHandle first = await guard.acquire();
      final SingleInstanceGuardHandle second = await guard.acquire();

      expect(identical(first, second), isTrue);

      await first.release();
    });
  });
}
