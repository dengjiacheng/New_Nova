import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/services/execution_asset_service.dart';
import 'package:nova_desk/src/data/clients/asset_api_client.dart';
import 'package:nova_desk/src/domain/entities/execution_asset.dart';
import 'package:nova_desk/src/domain/entities/template.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

class _FakeAssetClient implements AssetApiClient {
  final List<String> uploaded = <String>[];

  @override
  Future<void> deleteAsset(String assetId) async {
    uploaded.remove(assetId);
  }

  @override
  Future<UploadAssetResponse> uploadFile({
    required String filePath,
    required Map<String, String> headers,
  }) async {
    uploaded.add(filePath);
    return UploadAssetResponse(
      assetId: 'asset-${uploaded.length}',
      downloadUrl: 'mock://$filePath',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      checksum: headers['X-Checksum'] ?? '',
    );
  }
}

class _SilentLogger extends AppLogger {
  _SilentLogger() : super(appPaths: AppPaths(root: Directory.systemTemp));

  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {Object? cause}) async {}
}

void main() {
  late File tempFile;
  late _FakeAssetClient client;
  late ExecutionAssetService service;

  setUp(() async {
    tempFile = await File('${Directory.systemTemp.path}/asset_test.txt').create();
    await tempFile.writeAsString('hello');
    client = _FakeAssetClient();
    service = ExecutionAssetService(
      assetApiClient: client,
      logger: _SilentLogger(),
      maxFileSizeBytes: 1024,
    );
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  test('uploads file fields and returns asset info', () async {
    final ScriptTemplate template = ScriptTemplate(
      templateId: 'tpl-1',
      scriptId: 'SCRIPT_LOGIN',
      name: '模板',
      description: null,
      version: 1,
      fields: <TemplateField>[
        TemplateField(key: 'file1', type: 'file', label: '文件', value: tempFile.path),
      ],
      metadata: TemplateMetadata(
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final List<UploadedAsset> assets = await service.uploadAssets(template);
    expect(assets.length, 1);
    expect(assets.first.fieldKey, 'file1');
  });

  test('throws error when file missing', () async {
    final ScriptTemplate template = ScriptTemplate(
      templateId: 'tpl-1',
      scriptId: 'SCRIPT_LOGIN',
      name: '模板',
      description: null,
      version: 1,
      fields: const <TemplateField>[
        TemplateField(key: 'file1', type: 'file', label: '文件', value: '/path/not/exist'),
      ],
      metadata: TemplateMetadata(
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    expect(() => service.uploadAssets(template), throwsA(isA<AssetUploadException>()));
  });
}
