import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/app_event.dart';
import '../events/app_event_bus.dart';
import '../../presentation/state/execution_state.dart';

class ExecutionController extends StateNotifier<ExecutionState> {
  ExecutionController({required AppEventBus eventBus})
      : _eventBus = eventBus,
        super(const ExecutionState.initial()) {
    _subscription = _eventBus.stream.listen(_handleEvent);
  }

  final AppEventBus _eventBus;
  StreamSubscription<AppEvent>? _subscription;

  void _handleEvent(AppEvent event) {
    if (event is ExecutionProgressed) {
      final Map<String, ExecutionView> updated =
          Map<String, ExecutionView>.from(state.executions);
      final ExecutionView previous = updated[event.executionId] ??
          ExecutionView(
            executionId: event.executionId,
            status: event.payload['status'] as String? ?? 'UNKNOWN',
            progress: (event.payload['progress'] as num?)?.toDouble() ?? 0,
            payload: event.payload,
          );
      updated[event.executionId] = previous.copyWith(
        status: event.payload['status'] as String? ?? previous.status,
        progress: (event.payload['progress'] as num?)?.toDouble() ?? previous.progress,
        payload: event.payload,
      );
      state = state.copyWith(executions: updated);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
