import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/admin_tools_service.dart';
import '../../domain/entities/agent_package.dart';
import '../../presentation/state/admin_tools_state.dart';

class AdminToolsController extends StateNotifier<AdminToolsState> {
  AdminToolsController({required AdminToolsService service})
      : _service = service,
        super(AdminToolsState.initial());

  final AdminToolsService _service;

  Future<void> loadPackages() async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
    );
    try {
      final List<AgentPackage> packages = await _fetchAndSortPackages();
      state = state.copyWith(
        loading: false,
        packages: packages,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: '加载失败：${_describeError(error)}',
      );
    }
  }

  Future<void> uploadPackage({
    required File file,
    required String versionName,
    required int versionCode,
    String? releaseNotes,
    String? checksum,
  }) async {
    state = state.copyWith(
      uploading: true,
      uploadProgress: 0,
      errorMessage: null,
      successMessage: null,
    );
    try {
      final String resolvedChecksum =
          checksum ?? await _service.computeSha256(file);
      final AgentPackage package = await _service.uploadPackage(
        file: file,
        versionName: versionName,
        versionCode: versionCode,
        releaseNotes: releaseNotes,
        checksum: resolvedChecksum,
        onSendProgress: (int sent, int total) {
          if (total <= 0) {
            return;
          }
          state = state.copyWith(
            uploadProgress: sent / total,
          );
        },
      );
      final List<AgentPackage> packages = await _fetchAndSortPackages();
      state = state.copyWith(
        uploading: false,
        uploadProgress: 1,
        packages: packages,
        successMessage: '已上传 Agent 包 ${package.versionName} (${package.versionCode})',
      );
    } catch (error) {
      state = state.copyWith(
        uploading: false,
        errorMessage: '上传失败：${_describeError(error)}',
      );
    }
  }

  Future<void> activatePackage({
    required String packageId,
    String? notes,
  }) async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _service.activatePackage(packageId: packageId, notes: notes);
      final List<AgentPackage> packages = await _fetchAndSortPackages();
      AgentPackage? activated;
      for (final AgentPackage pkg in packages) {
        if (pkg.packageId == packageId) {
          activated = pkg;
          break;
        }
      }
      state = state.copyWith(
        loading: false,
        packages: packages,
        successMessage: activated != null
            ? '已设置 ${activated.versionName} (${activated.versionCode}) 为当前版本'
            : '已更新当前版本',
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: '更新失败：${_describeError(error)}',
      );
    }
  }

  Future<void> deletePackage(String packageId) async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await _service.deletePackage(packageId);
      final List<AgentPackage> packages = await _fetchAndSortPackages();
      state = state.copyWith(
        loading: false,
        packages: packages,
        successMessage: '已删除 Agent 包 $packageId',
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: '删除失败：${_describeError(error)}',
      );
    }
  }

  Future<String> computeChecksum(File file) {
    return _service.computeSha256(file);
  }

  void clearMessages() {
    state = state.copyWith(
      errorMessage: null,
      successMessage: null,
    );
  }

  Future<List<AgentPackage>> _fetchAndSortPackages() async {
    final List<AgentPackage> packages = await _service.fetchPackages();
    packages.sort(
      (AgentPackage a, AgentPackage b) => b.uploadedAt.compareTo(a.uploadedAt),
    );
    return List<AgentPackage>.unmodifiable(packages);
  }

  String _describeError(Object error) {
    if (error is AdminToolsException) {
      return error.message;
    }
    return error.toString();
  }
}
