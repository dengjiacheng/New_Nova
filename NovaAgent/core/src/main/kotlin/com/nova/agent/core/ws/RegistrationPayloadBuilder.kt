package com.nova.agent.core.ws

import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.telemetry.HeartbeatStateStore
import com.nova.agent.execution.history.ExecutionHistory
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import java.time.Clock
import java.time.format.DateTimeFormatter
import java.util.UUID

private val ISO_INSTANT_FORMATTER: DateTimeFormatter = DateTimeFormatter.ISO_INSTANT

interface RegistrationPayloadProvider {
    fun buildJson(isReconnect: Boolean): String
    fun build(isReconnect: Boolean): AgentEnvelope<AgentRegisterPayload>
}

class RegistrationPayloadBuilder(
    private val config: AgentConfig,
    private val executionHistory: ExecutionHistory,
    private val heartbeatStateStore: HeartbeatStateStore,
    private val moshi: Moshi,
    private val clock: Clock = Clock.systemUTC(),
    private val correlationIdProvider: () -> String = { "REG-${UUID.randomUUID()}" }
) : RegistrationPayloadProvider {

    private val envelopeType = Types.newParameterizedType(
        AgentEnvelope::class.java,
        AgentRegisterPayload::class.java
    )
    private val adapter = moshi.adapter<AgentEnvelope<AgentRegisterPayload>>(envelopeType)

    override fun build(isReconnect: Boolean): AgentEnvelope<AgentRegisterPayload> {
        val recentExecutions = if (isReconnect) {
            executionHistory.latest(ExecutionHistory.DEFAULT_CAPACITY)
        } else {
            emptyList()
        }
        val metricsSnapshot = heartbeatStateStore.latest()
        val payload = AgentRegisterPayload(
            tenantId = config.tenantId,
            userId = config.userId,
            pcId = config.pcId,
            deviceId = config.deviceId,
            agentVersion = config.agentVersion,
            buildNumber = config.buildNumber,
            scriptCatalog = config.scriptCatalog,
            capabilities = config.capabilities,
            recentExecutions = recentExecutions,
            metricsSnapshot = metricsSnapshot
        )
        return AgentEnvelope(
            type = "EVENT",
            topic = "agents.status",
            correlationId = correlationIdProvider(),
            timestamp = ISO_INSTANT_FORMATTER.format(clock.instant()),
            payload = payload
        )
    }

    override fun buildJson(isReconnect: Boolean): String = toJson(build(isReconnect))

    fun toJson(envelope: AgentEnvelope<AgentRegisterPayload>): String = adapter.toJson(envelope)
}
