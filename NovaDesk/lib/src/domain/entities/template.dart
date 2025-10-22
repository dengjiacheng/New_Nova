import 'dart:convert';

import 'package:meta/meta.dart';

@immutable
class ScriptTemplate {
  const ScriptTemplate({
    required this.templateId,
    required this.scriptId,
    required this.name,
    required this.description,
    required this.version,
    required this.fields,
    required this.metadata,
  });

  final String templateId;
  final String scriptId;
  final String name;
  final String? description;
  final int version;
  final List<TemplateField> fields;
  final TemplateMetadata metadata;

  ScriptTemplate copyWith({
    String? name,
    String? description,
    int? version,
    List<TemplateField>? fields,
    TemplateMetadata? metadata,
  }) {
    return ScriptTemplate(
      templateId: templateId,
      scriptId: scriptId,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      fields: fields ?? this.fields,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'templateId': templateId,
        'scriptId': scriptId,
        'name': name,
        'description': description,
        'version': version,
        'fields': fields.map((TemplateField field) => field.toJson()).toList(),
        'metadata': metadata.toJson(),
      };

  static ScriptTemplate fromJson(Map<String, dynamic> json) {
    final String templateId = json['templateId'] as String? ??
        (throw const FormatException('missing templateId'));
    final String scriptId = json['scriptId'] as String? ??
        (throw const FormatException('missing scriptId'));
    final List<dynamic> fieldList = json['fields'] as List<dynamic>? ?? <dynamic>[];
    return ScriptTemplate(
      templateId: templateId,
      scriptId: scriptId,
      name: json['name'] as String? ?? '未命名模板',
      description: json['description'] as String?,
      version: json['version'] as int? ?? 1,
      fields: fieldList
          .whereType<Map<String, dynamic>>()
          .map(TemplateField.fromJson)
          .toList(),
      metadata: TemplateMetadata.fromJson(
        (json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

@immutable
class TemplateField {
  const TemplateField({
    required this.key,
    required this.type,
    required this.label,
    this.value,
    this.required,
    this.description,
    this.options,
  });

  final String key;
  final String type;
  final String label;
  final dynamic value;
  final bool? required;
  final String? description;
  final Map<String, dynamic>? options;

  TemplateField copyWith({
    String? label,
    dynamic value,
    bool? required,
    String? description,
    Map<String, dynamic>? options,
  }) {
    return TemplateField(
      key: key,
      type: type,
      label: label ?? this.label,
      value: value ?? this.value,
      required: required ?? this.required,
      description: description ?? this.description,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'type': type,
        'label': label,
        'value': value,
        if (required != null) 'required': required,
        if (description != null) 'description': description,
        if (options != null) 'options': options,
      };

  static TemplateField fromJson(Map<String, dynamic> json) {
    return TemplateField(
      key: json['key'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'string',
      label: json['label'] as String? ?? json['key'] as String? ?? '字段',
      value: json['value'],
      required: json['required'] as bool?,
      description: json['description'] as String?,
      options: json['options'] as Map<String, dynamic>?,
    );
  }
}

@immutable
class TemplateMetadata {
  const TemplateMetadata({
    required this.createdAt,
    required this.updatedAt,
    this.lastExecutedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastExecutedAt;

  TemplateMetadata copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastExecutedAt,
  }) {
    return TemplateMetadata(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (lastExecutedAt != null) 'lastExecutedAt': lastExecutedAt!.toUtc().toIso8601String(),
      };

  static TemplateMetadata fromJson(Map<String, dynamic> json) {
    final DateTime createdAt = DateTime.parse(
      json['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
    ).toUtc();
    final DateTime updatedAt = DateTime.parse(
      json['updatedAt'] as String? ?? createdAt.toIso8601String(),
    ).toUtc();
    final String? lastExecuted = json['lastExecutedAt'] as String?;
    return TemplateMetadata(
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastExecutedAt: lastExecuted != null ? DateTime.parse(lastExecuted).toUtc() : null,
    );
  }
}
