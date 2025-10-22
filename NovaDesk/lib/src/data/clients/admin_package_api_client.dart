import 'dart:io';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../../domain/entities/agent_package.dart';

typedef ProgressCallback = void Function(int sent, int total);

class AdminPackageApiClient {
  AdminPackageApiClient(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<List<AgentPackage>> listPackages() async {
    final Response<Map<String, dynamic>> response =
        await _dio.get<Map<String, dynamic>>('/api/admin/agent-packages');
    final Map<String, dynamic> data =
        (response.data?['data'] as Map<String, dynamic>?) ??
            response.data ??
            <String, dynamic>{};
    final List<dynamic> items = data['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map((dynamic item) =>
            AgentPackage.fromJson(item as Map<String, dynamic>? ?? <String, dynamic>{}))
        .toList();
  }

  Future<AgentPackage> uploadPackage({
    required File file,
    required String versionName,
    required int versionCode,
    String? releaseNotes,
    String? checksum,
    ProgressCallback? onSendProgress,
  }) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
      'versionName': versionName,
      'versionCode': versionCode,
      if (releaseNotes != null && releaseNotes.isNotEmpty) 'releaseNotes': releaseNotes,
      if (checksum != null && checksum.isNotEmpty) 'checksum': checksum,
    });
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/api/admin/agent-packages',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
    final Map<String, dynamic> data =
        (response.data?['data'] as Map<String, dynamic>?) ??
            response.data ??
            <String, dynamic>{};
    return AgentPackage.fromJson(data);
  }

  Future<void> activatePackage(String packageId, {String? notes}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/admin/agent-packages/$packageId/activate',
      data: notes != null && notes.isNotEmpty ? <String, dynamic>{'notes': notes} : null,
    );
  }

  Future<void> deletePackage(String packageId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/api/admin/agent-packages/$packageId',
    );
  }

  Future<AgentPackage?> fetchLatest() async {
    final Response<Map<String, dynamic>> response =
        await _dio.get<Map<String, dynamic>>('/api/agent-packages/latest');
    if (response.statusCode == 200 && response.data != null) {
      final Map<String, dynamic> data =
          (response.data!['data'] as Map<String, dynamic>?) ?? response.data!;
      if (data.isEmpty) {
        return null;
      }
      return AgentPackage.fromJson(data);
    }
    return null;
  }
}
