import 'package:meta/meta.dart';

import '../../domain/events/core_event.dart';

/// 应用层经过解析后的事件集合，供状态管理与 UI 使用。
@immutable
abstract class AppEvent {
  const AppEvent();
}

class ConnectionStateChanged extends AppEvent {
  const ConnectionStateChanged({
    required this.connected,
    required this.reason,
  });

  final bool connected;
  final String reason;
}

class ExecutionProgressed extends AppEvent {
  const ExecutionProgressed({
    required this.executionId,
    required this.payload,
    required this.traceId,
  });

  final String executionId;
  final Map<String, dynamic> payload;
  final String traceId;
}

class UnknownCoreEventReceived extends AppEvent {
  const UnknownCoreEventReceived(this.coreEvent);

  final CoreEvent coreEvent;
}
