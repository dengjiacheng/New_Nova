import '../../data/repositories/template_repository.dart';
import '../../domain/entities/template.dart';

class TemplateService {
  TemplateService({
    required TemplateRepository repository,
  }) : _repository = repository;

  final TemplateRepository _repository;

  Future<List<ScriptTemplate>> listTemplates(String scriptId) {
    return _repository.listByScript(scriptId);
  }

  Future<ScriptTemplate> createTemplate({
    required String scriptId,
    required String name,
    String? description,
    List<TemplateField>? fields,
  }) {
    return _repository.create(
      scriptId: scriptId,
      name: name,
      description: description,
      fields: fields,
    );
  }

  Future<ScriptTemplate> updateTemplate(
    ScriptTemplate template,
    {
    String? name,
    String? description,
    List<TemplateField>? fields,
  }) async {
    final ScriptTemplate updated = template.copyWith(
      name: name,
      description: description,
      version: template.version + 1,
      fields: fields ?? template.fields,
    );
    return _repository.save(updated);
  }

  Future<ScriptTemplate> duplicateTemplate(
    ScriptTemplate template, {
    String? newName,
  }) async {
    final ScriptTemplate copy = template.copyWith(
      name: newName ?? '${template.name} 副本',
      metadata: TemplateMetadata(
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return _repository.create(
      scriptId: copy.scriptId,
      name: copy.name,
      description: copy.description,
      fields: copy.fields.map((TemplateField field) => field.copyWith()).toList(),
    );
  }

  Future<void> deleteTemplate(String scriptId, String templateId) {
    return _repository.delete(scriptId, templateId);
  }

  Future<ScriptTemplate?> loadTemplate(String scriptId, String templateId) {
    return _repository.read(scriptId, templateId);
  }

  Future<ScriptTemplate> markExecuted(ScriptTemplate template) async {
    final TemplateMetadata metadata = template.metadata.copyWith(
      lastExecutedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    return _repository.save(template.copyWith(metadata: metadata));
  }

  /// 根据 schema 校验模板字段是否齐全。
  /// schema 使用 `{key, required}` 格式。
  List<String> validateRequiredFields(
    ScriptTemplate template,
    Iterable<Map<String, dynamic>> schema,
  ) {
    final Map<String, TemplateField> fieldByKey = {
      for (final TemplateField field in template.fields) field.key: field,
    };
    final List<String> missing = <String>[];
    for (final Map<String, dynamic> entry in schema) {
      final String? key = entry['key'] as String?;
      final bool required = entry['required'] as bool? ?? false;
      if (key == null || !required) {
        continue;
      }
      final TemplateField? field = fieldByKey[key];
      if (field == null || _isEmptyValue(field.value)) {
        missing.add(key);
      }
    }
    return missing;
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable || value is Map) {
      final int length = value is Iterable
          ? value.length
          : (value as Map<dynamic, dynamic>).length;
      return length == 0;
    }
    return false;
  }

  TemplateField updateFieldValue(
    TemplateField field,
    dynamic value,
  ) {
    return field.copyWith(value: value);
  }

  List<TemplateField> upsertField(
    List<TemplateField> fields,
    TemplateField field,
  ) {
    final List<TemplateField> next = List<TemplateField>.from(fields);
    final int index = next.indexWhere((TemplateField item) => item.key == field.key);
    if (index >= 0) {
      next[index] = field;
    } else {
      next.add(field);
    }
    return next;
  }
}
