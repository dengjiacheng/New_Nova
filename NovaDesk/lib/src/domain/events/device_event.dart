import 'package:meta/meta.dart';

import '../entities/device_snapshot.dart';

@immutable
abstract class DeviceEvent {
  const DeviceEvent();
}

class DeviceSyncCompleted extends DeviceEvent {
  const DeviceSyncCompleted({
    required this.snapshots,
    required this.changed,
    required this.removedDeviceIds,
    required this.syncedAt,
  });

  final List<DeviceSnapshot> snapshots;
  final List<DeviceSnapshot> changed;
  final List<String> removedDeviceIds;
  final DateTime syncedAt;
}

class ServerDeviceStatePushed extends DeviceEvent {
  const ServerDeviceStatePushed({
    required this.payload,
    required this.traceId,
  });

  final Map<String, dynamic> payload;
  final String traceId;
}
