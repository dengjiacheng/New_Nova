import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  late AppPaths appPaths;
  late TemplateRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('template_repo_test_');
    appPaths = AppPaths(root: tempDir);
    repository = TemplateRepository(appPaths: appPaths, logger: _SilentLogger(appPaths));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create and list templates', () async {
    final ScriptTemplate template = await repository.create(
      scriptId: 'SCRIPT_LOGIN',
      name: '默认模板',
    );

    final List<ScriptTemplate> listed = await repository.listByScript('SCRIPT_LOGIN');
    expect(listed, isNotEmpty);
    expect(listed.first.templateId, template.templateId);
  });

  test('save updates timestamp', () async {
    ScriptTemplate template = await repository.create(
      scriptId: 'SCRIPT_LOGIN',
      name: '模板1',
    );
    final DateTime original = template.metadata.updatedAt;
    template = await repository.save(template.copyWith(name: '模板2'));
    expect(template.name, '模板2');
    expect(template.metadata.updatedAt.isAfter(original), isTrue);
  });

  test('delete removes file', () async {
    final ScriptTemplate template = await repository.create(
      scriptId: 'SCRIPT_LOGIN',
      name: '模板3',
    );
    await repository.delete(template.scriptId, template.templateId);
    final List<ScriptTemplate> listed = await repository.listByScript('SCRIPT_LOGIN');
    expect(listed, isEmpty);
  });
}
