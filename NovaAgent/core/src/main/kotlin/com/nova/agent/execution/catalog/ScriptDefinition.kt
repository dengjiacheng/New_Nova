package com.nova.agent.execution.catalog

import com.nova.agent.execution.runner.ScriptRunner

data class ScriptDefinition(
    val id: String,
    val version: String,
    val handler: ScriptRunner,
    val schema: ParameterSchema,
    val capabilities: Map<String, Boolean> = emptyMap()
)

class ScriptRegistry {
    private val definitions = LinkedHashMap<String, ScriptDefinition>()

    fun register(definition: ScriptDefinition) {
        definitions[definition.id] = definition
    }

    fun find(id: String): ScriptDefinition? = definitions[id]

    fun all(): List<ScriptDefinition> = definitions.values.toList()
}
