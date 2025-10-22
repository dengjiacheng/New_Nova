package com.nova.agent.core.ws

import com.nova.agent.core.telemetry.HeartbeatSnapshot
import com.nova.agent.execution.catalog.ScriptDescriptor
import com.nova.agent.execution.history.ExecutionSnapshot
import com.squareup.moshi.Json

data class AgentRegisterPayload(
    @Json(name = "event")
    val event: String = "REGISTER",
    @Json(name = "tenantId")
    val tenantId: String,
    @Json(name = "userId")
    val userId: String,
    @Json(name = "pcId")
    val pcId: String,
    @Json(name = "deviceId")
    val deviceId: String,
    @Json(name = "agentVersion")
    val agentVersion: String,
    @Json(name = "buildNumber")
    val buildNumber: String,
    @Json(name = "scriptCatalog")
    val scriptCatalog: List<ScriptDescriptor>,
    @Json(name = "capabilities")
    val capabilities: Map<String, Boolean>,
    @Json(name = "recentExecutions")
    val recentExecutions: List<ExecutionSnapshot> = emptyList(),
    @Json(name = "metricsSnapshot")
    val metricsSnapshot: HeartbeatSnapshot? = null
)
