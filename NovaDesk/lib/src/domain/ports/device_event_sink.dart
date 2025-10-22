import 'dart:async';

import '../events/device_event.dart';

abstract class DeviceEventSink {
  Stream<DeviceEvent> get stream;

  void publish(DeviceEvent event);

  Future<void> dispose();
}
