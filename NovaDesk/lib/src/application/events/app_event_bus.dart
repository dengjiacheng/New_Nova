import 'dart:async';

import 'app_event.dart';

/// 应用内派发事件的总线，使用广播流供多订阅者消费。
class AppEventBus {
  AppEventBus() : _controller = StreamController<AppEvent>.broadcast();

  final StreamController<AppEvent> _controller;

  Stream<AppEvent> get stream => _controller.stream;

  void publish(AppEvent event) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
