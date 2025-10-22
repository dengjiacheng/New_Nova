import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/template_service.dart';
import '../../domain/entities/template.dart';
import '../../presentation/state/template_state.dart';

class TemplateController extends StateNotifier<TemplateState> {
  TemplateController({required TemplateService service})
      : _service = service,
        super(const TemplateState.initial());

  final TemplateService _service;

  Future<void> load(String scriptId) async {
    state = state.copyWith(loading: true);
    try {
      final List<ScriptTemplate> templates =
          await _service.listTemplates(scriptId);
      final Map<String, List<ScriptTemplate>> next =
          Map<String, List<ScriptTemplate>>.from(state.templatesByScript);
      next[scriptId] = templates;
      state = state.copyWith(templatesByScript: next, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<ScriptTemplate> create(String scriptId, String name) async {
    final ScriptTemplate template =
        await _service.createTemplate(scriptId: scriptId, name: name);
    await load(scriptId);
    return template;
  }

  Future<void> delete(String scriptId, String templateId) async {
    await _service.deleteTemplate(scriptId, templateId);
    await load(scriptId);
  }
}
