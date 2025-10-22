import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/services/template_service.dart';
import 'package:nova_desk/src/data/repositories/template_repository.dart';
import 'package:nova_desk/src/domain/entities/template.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/app_paths.dart';

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
  late Directory tempDir;
  late TemplateService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('template_service_test_');
    final AppPaths paths = AppPaths(root: tempDir);
    service = TemplateService(
      repository: TemplateRepository(appPaths: paths, logger: _SilentLogger(paths)),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create and duplicate template', () async {
    final ScriptTemplate template = await service.createTemplate(
      scriptId: 'SCRIPT_LOGIN',
      name: '模板A',
    );
    final ScriptTemplate duplicate = await service.duplicateTemplate(template);
    expect(duplicate.templateId, isNot(template.templateId));
    expect(duplicate.name.contains('副本'), isTrue);
  });

  test('validateRequiredFields detects missing keys', () async {
    final ScriptTemplate template = await service.createTemplate(
      scriptId: 'SCRIPT_LOGIN',
      name: '模板B',
      fields: const <TemplateField>[
        TemplateField(key: 'username', type: 'string', label: '用户名', value: 'demo'),
      ],
    );

    final List<String> missing = service.validateRequiredFields(template, <Map<String, dynamic>>[
      <String, dynamic>{'key': 'username', 'required': true},
      <String, dynamic>{'key': 'password', 'required': true},
    ]);

    expect(missing, equals(<String>['password']));
  });
}
