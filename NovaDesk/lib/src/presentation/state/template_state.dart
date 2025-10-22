import 'package:meta/meta.dart';

import '../../domain/entities/template.dart';

@immutable
class TemplateState {
  const TemplateState({
    required this.templatesByScript,
    required this.loading,
  });

  const TemplateState.initial()
      : templatesByScript = const <String, List<ScriptTemplate>>{},
        loading = false;

  final Map<String, List<ScriptTemplate>> templatesByScript;
  final bool loading;

  TemplateState copyWith({
    Map<String, List<ScriptTemplate>>? templatesByScript,
    bool? loading,
  }) {
    return TemplateState(
      templatesByScript: templatesByScript ?? this.templatesByScript,
      loading: loading ?? this.loading,
    );
  }

  List<ScriptTemplate> templatesFor(String scriptId) =>
      templatesByScript[scriptId] ?? const <ScriptTemplate>[];
}
