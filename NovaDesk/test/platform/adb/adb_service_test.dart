import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/platform/adb/adb_service.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

class _StubRunner extends ProcessRunner {
  _StubRunner(this.result);

  final ProcessResult result;

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async => result;
}

class _SilentLogger extends AppLogger {
  _SilentLogger() : super(appPaths: AppPaths(root: Directory.systemTemp));

  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {Object? cause}) async {}
}

void main() {
  test('parses adb devices output', () async {
    const String stdout = 'List of devices attached\n'
        'emulator-5554\tdevice usb:123 state:device\n'
        '192.168.1.10:5555\toffline\n';

    final ProcessAdbService service = ProcessAdbService(
      processRunner: _StubRunner(ProcessResult(0, 0, stdout, '')),
      logger: _SilentLogger(),
    );

    final List<AdbDeviceInfo> devices = await service.listDevices();
    expect(devices.length, 2);
    expect(devices.first.deviceId, 'emulator-5554');
    expect(devices.first.state, 'device');
    expect(devices.first.properties['usb'], '123');
  });

  test('throws when adb exits with error', () async {
    final ProcessAdbService service = ProcessAdbService(
      processRunner: _StubRunner(ProcessResult(1, 1, '', 'error')),
      logger: _SilentLogger(),
    );

    expect(() => service.listDevices(), throwsA(isA<AdbException>()));
  });
}
