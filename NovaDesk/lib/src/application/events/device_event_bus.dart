import 'dart:async';

import '../../domain/events/device_event.dart';
import '../../domain/ports/device_event_sink.dart';

class DeviceEventBus implements DeviceEventSink {
  DeviceEventBus() : _controller = StreamController<DeviceEvent>.broadcast();

  final StreamController<DeviceEvent> _controller;

  @override
  Stream<DeviceEvent> get stream => _controller.stream;

  @override
  void publish(DeviceEvent event) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(event);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
