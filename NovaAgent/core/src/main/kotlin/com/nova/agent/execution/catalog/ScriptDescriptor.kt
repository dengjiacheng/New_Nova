package com.nova.agent.execution.catalog

import com.squareup.moshi.Json

/**
 * Metadata describing an executable script bundled with the Agent.
 */
data class ScriptDescriptor(
    @Json(name = "id")
    val id: String,
    @Json(name = "version")
    val version: String,
    @Json(name = "checksum")
    val checksum: String? = null,
    @Json(name = "parameters")
    val parameters: ParameterSchema,
    @Json(name = "capabilities")
    val capabilities: Map<String, Boolean> = emptyMap()
)
