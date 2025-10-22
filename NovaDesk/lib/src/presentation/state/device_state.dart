import 'package:meta/meta.dart';

import '../../domain/entities/device_snapshot.dart';

@immutable
class DeviceState {
  const DeviceState({
    required this.devices,
    required this.lastUpdatedAt,
  });

  const DeviceState.initial()
      : devices = const <String, DeviceSnapshot>{},
        lastUpdatedAt = null;

  final Map<String, DeviceSnapshot> devices;
  final DateTime? lastUpdatedAt;

  DeviceState copyWith({
    Map<String, DeviceSnapshot>? devices,
    DateTime? lastUpdatedAt,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
