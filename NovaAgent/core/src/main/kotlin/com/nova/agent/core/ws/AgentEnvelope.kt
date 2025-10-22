package com.nova.agent.core.ws

import com.squareup.moshi.Json

data class AgentEnvelope<T>(
    @Json(name = "version")
    val version: String = "1.0",
    @Json(name = "type")
    val type: String,
    @Json(name = "topic")
    val topic: String,
    @Json(name = "correlationId")
    val correlationId: String,
    @Json(name = "timestamp")
    val timestamp: String,
    @Json(name = "payload")
    val payload: T
)
