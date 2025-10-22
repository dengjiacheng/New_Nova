package com.nova.agent.core.config

import com.nova.agent.execution.catalog.ScriptDescriptor

/**
 * Static runtime configuration used during Agent registration.
 */
data class AgentConfig(
    val tenantId: String,
    val userId: String,
    val pcId: String,
    val deviceId: String,
    val serverUrl: String,
    val deviceToken: String,
    val agentVersion: String,
    val buildNumber: String,
    val scriptCatalog: List<ScriptDescriptor>,
    val capabilities: Map<String, Boolean>,
    val wsUrl: String
)
