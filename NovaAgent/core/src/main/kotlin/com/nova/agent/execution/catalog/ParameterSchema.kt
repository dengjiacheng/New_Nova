package com.nova.agent.execution.catalog

import com.squareup.moshi.Json

data class ParameterSchema(
    @Json(name = "fields")
    val fields: List<ParameterField>,
    @Json(name = "constraints")
    val constraints: Map<String, Any?> = emptyMap()
)

data class ParameterField(
    @Json(name = "key")
    val key: String,
    @Json(name = "type")
    val type: ParameterFieldType,
    @Json(name = "label")
    val label: String,
    @Json(name = "required")
    val required: Boolean = false,
    @Json(name = "default")
    val defaultValue: Any? = null
)

enum class ParameterFieldType {
    STRING,
    PASSWORD,
    NUMBER,
    BOOLEAN,
    FILE
}
