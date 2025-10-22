import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/services/admin_tools_service.dart';
import 'package:nova_desk/src/data/clients/admin_package_api_client.dart';
import 'package:nova_desk/src/data/api/api_client.dart';
import 'package:nova_desk/src/domain/entities/agent_package.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

class _ThrowingApiClient extends AdminPackageApiClient {
  _ThrowingApiClient(this.exception)
      : super(ApiClient());

  final dio.DioException exception;

  @override
  Future<AgentPackage> uploadPackage({
    required File file,
    required String versionName,
    required int versionCode,
    String? releaseNotes,
    String? checksum,
    ProgressCallback? onSendProgress,
  }) async {
    throw exception;
  }

  @override
  Future<List<AgentPackage>> listPackages() async => <AgentPackage>[];

  @override
  Future<void> activatePackage(String packageId, {String? notes}) async {}

  @override
  Future<void> deletePackage(String packageId) async {
    throw exception;
  }

  @override
  Future<AgentPackage?> fetchLatest() async => null;
}

class _SilentLogger extends AppLogger {
  _SilentLogger(AppPaths paths) : super(appPaths: paths);

  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {Object? cause}) async {}
}

void main() {
  group('AdminToolsService', () {
    test('wraps checksum mismatch error into AdminToolsException', () async {
      final dio.DioException dioError = dio.DioException.badResponse(
        requestOptions: dio.RequestOptions(path: '/api/admin/agent-packages'),
        response: dio.Response<Map<String, dynamic>>(
          requestOptions: dio.RequestOptions(path: '/api/admin/agent-packages'),
          statusCode: 400,
          data: <String, dynamic>{
            'code': 'CHECKSUM_MISMATCH',
            'message': 'Checksum mismatch',
          },
        ),
      );

      final Directory tempDir = await Directory.systemTemp.createTemp('admin_tools_test_');
      final File file = File('${tempDir.path}/test.apk');
      await file.writeAsBytes(<int>[0, 1, 2, 3]);

      final AdminToolsService service = AdminToolsService(
        apiClient: _ThrowingApiClient(dioError),
        logger: _SilentLogger(AppPaths(root: tempDir)),
      );

      expect(
        () => service.uploadPackage(
          file: file,
          versionName: '1.0.0',
          versionCode: 1000,
          checksum: 'sha256:dummy',
        ),
        throwsA(
          isA<AdminToolsException>().having(
            (AdminToolsException e) => e.message,
            'message',
            contains('校验值不匹配'),
          ),
        ),
      );

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
  });

    test('wraps delete error into AdminToolsException', () async {
      final dio.DioException dioError = dio.DioException.badResponse(
        requestOptions: dio.RequestOptions(path: '/api/admin/agent-packages/AGP-1'),
        response: dio.Response<Map<String, dynamic>>(
          requestOptions: dio.RequestOptions(path: '/api/admin/agent-packages/AGP-1'),
          statusCode: 404,
          data: <String, dynamic>{
            'code': 'AGENT_PACKAGE_NOT_FOUND',
            'message': 'not found',
          },
        ),
      );

      final Directory tempDir = await Directory.systemTemp.createTemp('admin_tools_delete_');

      final AdminToolsService service = AdminToolsService(
        apiClient: _ThrowingApiClient(dioError),
        logger: _SilentLogger(AppPaths(root: tempDir)),
      );

      expect(
        () => service.deletePackage('AGP-1'),
        throwsA(
          isA<AdminToolsException>().having(
            (AdminToolsException e) => e.message,
            'message',
            contains('失败'),
          ),
        ),
      );

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
