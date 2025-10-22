import 'package:meta/meta.dart';

import '../../domain/entities/agent_package.dart';

const Object _noChange = Object();

@immutable
class AdminToolsState {
  const AdminToolsState({
    this.loading = false,
    this.uploading = false,
    this.uploadProgress = 0,
    this.packages = const <AgentPackage>[],
    this.errorMessage,
    this.successMessage,
  });

  final bool loading;
  final bool uploading;
  final double uploadProgress;
  final List<AgentPackage> packages;
  final String? errorMessage;
  final String? successMessage;

  AgentPackage? get activePackage {
    for (final AgentPackage package in packages) {
      if (package.isActive) {
        return package;
      }
    }
    return null;
  }

  AdminToolsState copyWith({
    Object? loading = _noChange,
    Object? uploading = _noChange,
    Object? uploadProgress = _noChange,
    Object? packages = _noChange,
    Object? errorMessage = _noChange,
    Object? successMessage = _noChange,
  }) {
    return AdminToolsState(
      loading: identical(loading, _noChange) ? this.loading : loading as bool,
      uploading: identical(uploading, _noChange) ? this.uploading : uploading as bool,
      uploadProgress: identical(uploadProgress, _noChange)
          ? this.uploadProgress
          : uploadProgress is num
              ? uploadProgress.toDouble()
              : uploadProgress as double,
      packages:
          identical(packages, _noChange) ? this.packages : packages as List<AgentPackage>,
      errorMessage:
          identical(errorMessage, _noChange) ? this.errorMessage : errorMessage as String?,
      successMessage: identical(successMessage, _noChange)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  static AdminToolsState initial() => const AdminToolsState();
}
