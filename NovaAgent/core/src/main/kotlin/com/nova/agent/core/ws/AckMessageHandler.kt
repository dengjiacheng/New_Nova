package com.nova.agent.core.ws

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.reporting.ReporterAckListener
import com.nova.agent.reporting.ReporterAckType
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi

class AckMessageHandler(
    moshi: Moshi,
    private val logger: AgentLogger,
    private val reporterAckListener: ReporterAckListener
) : InboundMessageListener {

    private val adapter = moshi.adapter(AckEnvelope::class.java)

    override suspend fun onMessage(text: String) {
        val envelope = runCatching { adapter.fromJson(text) }.getOrElse { error ->
            logger.warn("Failed to parse ACK envelope: ${error.message}")
            return
        } ?: return
        if (envelope.type != "ACK" || envelope.topic != "executions.ack") {
            return
        }
        val payload = envelope.payload ?: return
        if (payload.direction != "SERVER") {
            return
        }
        val correlationId = envelope.correlationId ?: return
        val ackType = ReporterAckType.values().find { it.name == payload.ackType }
        if (ackType == null) {
            logger.warn("Unknown ackType ${payload.ackType} for correlationId=$correlationId")
            return
        }
        val executionId = payload.executionId ?: ""
        reporterAckListener.onReporterAck(correlationId, ackType, executionId)
    }
}

@JsonClass(generateAdapter = true)
data class AckEnvelope(
    val version: String? = null,
    val type: String? = null,
    val topic: String? = null,
    val correlationId: String? = null,
    val payload: AckPayload? = null
)

@JsonClass(generateAdapter = true)
data class AckPayload(
    val direction: String? = null,
    val ackType: String? = null,
    val executionId: String? = null,
    val status: String? = null,
    val error: AckError? = null
)

@JsonClass(generateAdapter = true)
data class AckError(
    val code: String? = null,
    val message: String? = null
)
