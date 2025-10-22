import '../../domain/events/core_event.dart';
import '../../domain/events/device_event.dart';
import 'app_event.dart';

/// 将 CoreEvent 解析映射为具体的应用事件。
class CoreEventMapper {
  DeviceEvent? mapDeviceEvent(CoreEvent event) {
    switch (event.topic) {
      case 'agents.status':
      case 'DEVICE_STATUS_CHANGED':
        return ServerDeviceStatePushed(
          payload: event.payload,
          traceId: event.traceId,
        );
    }
    return null;
  }

  AppEvent? mapAppEvent(CoreEvent event) {
    switch (event.topic) {
      case 'executions.progress':
      case 'executions.result':
      case 'EXECUTION_PROGRESS':
        return ExecutionProgressed(
          executionId: event.payload['executionId'] as String? ?? 'unknown',
          payload: event.payload,
          traceId: event.traceId,
        );
      default:
        return UnknownCoreEventReceived(event);
    }
  }
}
