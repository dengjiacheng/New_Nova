import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/device_snapshot.dart';
import '../../domain/events/device_event.dart';
import '../../domain/ports/device_event_sink.dart';
import '../../presentation/state/device_state.dart';

class DeviceController extends StateNotifier<DeviceState> {
  DeviceController({required DeviceEventSink deviceEvents})
      : _deviceEvents = deviceEvents,
        super(const DeviceState.initial()) {
    _subscription = _deviceEvents.stream.listen(_handleEvent);
  }

  final DeviceEventSink _deviceEvents;
  StreamSubscription<DeviceEvent>? _subscription;

  void _handleEvent(DeviceEvent event) {
    if (event is DeviceSyncCompleted) {
      final Map<String, DeviceSnapshot> next = <String, DeviceSnapshot>{
        for (final DeviceSnapshot snapshot in event.snapshots)
          snapshot.deviceId: snapshot,
      };
      state = DeviceState(
        devices: next,
        lastUpdatedAt: event.syncedAt,
      );
      return;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
