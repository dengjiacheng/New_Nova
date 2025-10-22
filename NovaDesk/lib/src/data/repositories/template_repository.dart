import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/entities/template.dart';
import '../../platform/app_logger.dart';
import '../../platform/app_paths.dart';

class TemplateRepository {
  TemplateRepository({
    AppPaths? appPaths,
    AppLogger? logger,
    Uuid? uuid,
  })  : _appPaths = appPaths ?? AppPaths(),
        _logger = logger ?? AppLogger.defaultLogger(),
        _uuid = uuid ?? const Uuid();

  final AppPaths _appPaths;
  final AppLogger _logger;
  final Uuid _uuid;

  Future<List<ScriptTemplate>> listByScript(String scriptId) async {
    final Directory dir = await _ensureScriptDir(scriptId);
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<ScriptTemplate> templates = <ScriptTemplate>[];
    for (final FileSystemEntity entity in entities) {
      if (entity is! File) continue;
      final String content = await entity.readAsString();
      try {
        final Map<String, dynamic> json =
            jsonDecode(content) as Map<String, dynamic>;
        templates.add(ScriptTemplate.fromJson(json));
      } catch (error) {
        await _logger.error('Failed to decode template ${entity.path}', cause: error);
      }
    }
    templates.sort((ScriptTemplate a, ScriptTemplate b) =>
        b.metadata.updatedAt.compareTo(a.metadata.updatedAt));
    return templates;
  }

  Future<ScriptTemplate> create({
    required String scriptId,
    required String name,
    String? description,
    List<TemplateField>? fields,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final ScriptTemplate template = ScriptTemplate(
      templateId: 'tpl-${_uuid.v4()}',
      scriptId: scriptId,
      name: name,
      description: description,
      version: 1,
      fields: fields ?? const <TemplateField>[],
      metadata: TemplateMetadata(createdAt: now, updatedAt: now),
    );
    await _writeTemplate(template);
    return template;
  }

  Future<ScriptTemplate> save(ScriptTemplate template) async {
    final ScriptTemplate updated = template.copyWith(
      metadata: template.metadata.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await _writeTemplate(updated);
    return updated;
  }

  Future<void> delete(String scriptId, String templateId) async {
    final File file = await _templateFile(scriptId, templateId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<ScriptTemplate?> read(String scriptId, String templateId) async {
    final File file = await _templateFile(scriptId, templateId);
    if (!await file.exists()) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ScriptTemplate.fromJson(json);
    } catch (error) {
      await _logger.error('Failed to read template ${file.path}', cause: error);
      return null;
    }
  }

  Future<void> _writeTemplate(ScriptTemplate template) async {
    final File file = await _templateFile(template.scriptId, template.templateId);
    final Directory parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(template.toJson()),
    );
  }

  Future<Directory> _ensureScriptDir(String scriptId) async {
    final Directory dir = Directory(
      p.join(_appPaths.templatesDir.path, scriptId),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _templateFile(String scriptId, String templateId) async {
    final Directory dir = await _ensureScriptDir(scriptId);
    final String fileName = '$templateId.json';
    return File(p.join(dir.path, fileName));
  }
}
