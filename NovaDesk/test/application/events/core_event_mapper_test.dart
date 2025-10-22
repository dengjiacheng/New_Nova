import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/events/app_event.dart';
import 'package:nova_desk/src/application/events/core_event_mapper.dart';
import 'package:nova_desk/src/domain/events/core_event.dart';
import 'package:nova_desk/src/domain/events/device_event.dart';

void main() {
  group('CoreEventMapper', () {
    final CoreEventMapper mapper = CoreEventMapper();

    test('maps agents.status events to ServerDeviceStatePushed', () {
      final CoreEvent event = CoreEvent(
        topic: 'agents.status',
        traceId: 'trace-1',
        payload: <String, dynamic>{'event': 'REGISTER'},
      );

      final DeviceEvent? deviceEvent = mapper.mapDeviceEvent(event);
      expect(deviceEvent, isA<ServerDeviceStatePushed>());
      final ServerDeviceStatePushed pushed = deviceEvent! as ServerDeviceStatePushed;
      expect(pushed.traceId, 'trace-1');
      expect(pushed.payload['event'], 'REGISTER');
    });

    test('maps executions.progress to ExecutionProgressed', () {
      final CoreEvent event = CoreEvent(
        topic: 'executions.progress',
        traceId: 'trace-2',
        payload: <String, dynamic>{'executionId': 'exec-1', 'status': 'RUNNING'},
      );

      final AppEvent? appEvent = mapper.mapAppEvent(event);
      expect(appEvent, isA<ExecutionProgressed>());
      final ExecutionProgressed progressed = appEvent! as ExecutionProgressed;
      expect(progressed.executionId, 'exec-1');
      expect(progressed.payload['status'], 'RUNNING');
    });

    test('maps legacy DEVICE_STATUS_CHANGED topic for backward compatibility', () {
      final CoreEvent event = CoreEvent(
        topic: 'DEVICE_STATUS_CHANGED',
        traceId: 'trace-legacy-1',
        payload: <String, dynamic>{'event': 'HEARTBEAT'},
      );

      final DeviceEvent? deviceEvent = mapper.mapDeviceEvent(event);
      expect(deviceEvent, isA<ServerDeviceStatePushed>());
      final ServerDeviceStatePushed pushed = deviceEvent! as ServerDeviceStatePushed;
      expect(pushed.traceId, 'trace-legacy-1');
      expect(pushed.payload['event'], 'HEARTBEAT');
    });

    test('maps legacy EXECUTION_PROGRESS topic for backward compatibility', () {
      final CoreEvent event = CoreEvent(
        topic: 'EXECUTION_PROGRESS',
        traceId: 'trace-legacy-2',
        payload: <String, dynamic>{'executionId': 'exec-legacy', 'status': 'RUNNING'},
      );

      final AppEvent? appEvent = mapper.mapAppEvent(event);
      expect(appEvent, isA<ExecutionProgressed>());
      final ExecutionProgressed progressed = appEvent! as ExecutionProgressed;
      expect(progressed.executionId, 'exec-legacy');
      expect(progressed.traceId, 'trace-legacy-2');
    });

    test('maps executions.result to ExecutionProgressed', () {
      final CoreEvent event = CoreEvent(
        topic: 'executions.result',
        traceId: 'trace-3',
        payload: <String, dynamic>{'executionId': 'exec-2', 'status': 'SUCCESS'},
      );

      final AppEvent? appEvent = mapper.mapAppEvent(event);
      expect(appEvent, isA<ExecutionProgressed>());
      final ExecutionProgressed progressed = appEvent! as ExecutionProgressed;
      expect(progressed.traceId, 'trace-3');
      expect(progressed.payload['status'], 'SUCCESS');
    });

    test('returns UnknownCoreEventReceived for other topics', () {
      final CoreEvent event = CoreEvent(
        topic: 'system.notice',
        traceId: 'trace-4',
        payload: const <String, dynamic>{'event': 'BALANCE_LOW'},
      );

      final AppEvent? appEvent = mapper.mapAppEvent(event);
      expect(appEvent, isA<UnknownCoreEventReceived>());
      final UnknownCoreEventReceived unknown =
          appEvent! as UnknownCoreEventReceived;
      expect(unknown.coreEvent.topic, 'system.notice');
    });
  });
}
