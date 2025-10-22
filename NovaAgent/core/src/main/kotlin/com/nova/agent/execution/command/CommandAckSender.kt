package com.nova.agent.execution.command

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.ws.AgentEnvelope
import com.nova.agent.core.ws.OutboundMessageSender
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import java.time.Clock
import java.time.Instant
import java.time.format.DateTimeFormatter

open class CommandAckSender(
    private val outbound: OutboundMessageSender,
    moshi: Moshi,
    private val logger: AgentLogger,
    private val clock: Clock = Clock.systemUTC()
) {

    private val adapter = moshi.adapter<AgentEnvelope<CommandAckPayload>>(
        Types.newParameterizedType(
            AgentEnvelope::class.java,
            CommandAckPayload::class.java
        )
    )

    open suspend fun sendAccepted(correlationId: String, executionId: String) {
        send(
            correlationId = correlationId,
            payload = CommandAckPayload(
                direction = "AGENT",
                ackType = "COMMAND",
                executionId = executionId,
                status = "ACCEPTED",
                error = null
            )
        )
    }

    open suspend fun sendRejected(correlationId: String, executionId: String, errorCode: String, message: String) {
        send(
            correlationId = correlationId,
            payload = CommandAckPayload(
                direction = "AGENT",
                ackType = "COMMAND",
                executionId = executionId,
                status = "REJECTED",
                error = CommandAckError(code = errorCode, message = message)
            )
        )
    }

    private suspend fun send(correlationId: String, payload: CommandAckPayload) {
        val envelope = AgentEnvelope(
            type = "ACK",
            topic = "executions.ack",
            correlationId = correlationId,
            timestamp = clock.instant().toIsoString(),
            payload = payload
        )
        val success = outbound.sendMessage(adapter.toJson(envelope))
        if (!success) {
            logger.warn("Failed to send command ACK correlationId=$correlationId status=${payload.status}")
        }
    }

    private fun Instant.toIsoString(): String = DateTimeFormatter.ISO_INSTANT.format(this)
}

data class CommandAckPayload(
    val direction: String,
    val ackType: String,
    val executionId: String,
    val status: String,
    val error: CommandAckError?
)

data class CommandAckError(
    val code: String,
    val message: String
)
