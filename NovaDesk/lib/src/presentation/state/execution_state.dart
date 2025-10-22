import 'package:meta/meta.dart';

@immutable
class ExecutionState {
  const ExecutionState({
    required this.executions,
  });

  const ExecutionState.initial() : executions = const <String, ExecutionView>{};

  final Map<String, ExecutionView> executions;

  ExecutionState copyWith({
    Map<String, ExecutionView>? executions,
  }) {
    return ExecutionState(
      executions: executions ?? this.executions,
    );
  }
}

@immutable
class ExecutionView {
  const ExecutionView({
    required this.executionId,
    required this.status,
    required this.progress,
    required this.payload,
  });

  final String executionId;
  final String status;
  final double progress;
  final Map<String, dynamic> payload;

  ExecutionView copyWith({
    String? executionId,
    String? status,
    double? progress,
    Map<String, dynamic>? payload,
  }) {
    return ExecutionView(
      executionId: executionId ?? this.executionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      payload: payload ?? this.payload,
    );
  }
}
