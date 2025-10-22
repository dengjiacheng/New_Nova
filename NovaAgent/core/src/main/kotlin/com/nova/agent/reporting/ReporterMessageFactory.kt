package com.nova.agent.reporting

import com.nova.agent.core.ws.AgentEnvelope
import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.reporting.events.AttachmentEvent
import com.nova.agent.reporting.events.ExecutionResultEvent
import com.nova.agent.reporting.events.LogEvent
import com.nova.agent.reporting.events.ProgressEvent
import com.nova.agent.reporting.events.ProgressStatus
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import java.time.Clock
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID

class ReporterMessageFactory(
    private val moshi: Moshi,
    private val clock: Clock = Clock.systemUTC(),
    private val correlationIdProvider: () -> String = { UUID.randomUUID().toString() }
) {

    private val progressAdapter = adapterFor<ProgressPayload>()
    private val logAdapter = adapterFor<LogPayload>()
    private val attachmentAdapter = adapterFor<AttachmentPayload>()
    private val resultAdapter = adapterFor<ResultPayload>()

    fun progress(event: ProgressEvent): ReporterMessage =
        ReporterMessage(
            correlationId = event.executionId.ifBlank { correlationIdProvider() },
            ackType = ReporterAckType.PROGRESS,
            executionId = event.executionId,
            json = progressAdapter.toJson(
                envelope(
                    type = "EVENT",
                    topic = "executions.progress",
                    payload = ProgressPayload(
                        executionId = event.executionId,
                        eventType = "STEP",
                        stepIndex = event.stepIndex,
                        stepName = event.stepName,
                        status = event.status.toWireValue(),
                        timestamp = event.timestamp.toIsoString()
                    )
                )
            )
        )

    fun log(event: LogEvent): ReporterMessage =
        ReporterMessage(
            correlationId = event.executionId.ifBlank { correlationIdProvider() },
            ackType = ReporterAckType.PROGRESS,
            executionId = event.executionId,
            json = logAdapter.toJson(
                envelope(
                    type = "EVENT",
                    topic = "executions.progress",
                    payload = LogPayload(
                        executionId = event.executionId,
                        eventType = "LOG",
                        level = event.level.name,
                        message = event.message,
                        timestamp = event.timestamp.toIsoString()
                    )
                )
            )
        )

    fun attachment(event: AttachmentEvent): ReporterMessage =
        ReporterMessage(
            correlationId = event.executionId.ifBlank { correlationIdProvider() },
            ackType = ReporterAckType.PROGRESS,
            executionId = event.executionId,
            json = attachmentAdapter.toJson(
                envelope(
                    type = "EVENT",
                    topic = "executions.progress",
                    payload = AttachmentPayload(
                        executionId = event.executionId,
                        eventType = "ATTACHMENT",
                        attachmentId = event.attachmentId,
                        type = event.type.name,
                        fileName = event.fileName,
                        contentType = event.contentType,
                        data = event.data,
                        downloadUrl = event.downloadUrl,
                        timestamp = event.timestamp.toIsoString()
                    )
                )
            )
        )

    fun result(event: ExecutionResultEvent): ReporterMessage {
        val correlationId = event.executionId.ifBlank { correlationIdProvider() }
        return ReporterMessage(
            correlationId = correlationId,
            ackType = ReporterAckType.RESULT,
            executionId = event.executionId,
            json = resultAdapter.toJson(
                envelope(
                    type = "REPLY",
                    topic = "executions.result",
                    payload = ResultPayload(
                        executionId = event.executionId,
                        status = event.status.toWireValue(),
                        summary = event.summary,
                        durationMs = event.durationMs,
                        error = event.error?.let {
                            ResultError(
                                code = it.code,
                                message = it.message,
                                details = it.details
                            )
                        },
                        outputs = event.outputs
                    ),
                    correlationIdOverride = correlationId
                )
            )
        )
    }

    private fun <T> envelope(
        type: String,
        topic: String,
        payload: T,
        correlationIdOverride: String? = null
    ): AgentEnvelope<T> = AgentEnvelope(
        type = type,
        topic = topic,
        correlationId = correlationIdOverride ?: correlationIdProvider(),
        timestamp = clock.instant().toIsoString(),
        payload = payload
    )

    private inline fun <reified T> adapterFor(): com.squareup.moshi.JsonAdapter<AgentEnvelope<T>> {
        val envelopeType = Types.newParameterizedType(AgentEnvelope::class.java, T::class.java)
        return moshi.adapter(envelopeType)
    }

    private fun Instant.toIsoString(): String = DateTimeFormatter.ISO_INSTANT.format(this)

    private fun ProgressStatus.toWireValue(): String = when (this) {
        ProgressStatus.RUNNING -> "RUNNING"
        ProgressStatus.SUCCESS -> "SUCCESS"
        ProgressStatus.FAILED -> "FAILED"
    }

    private fun ExecutionStatus.toWireValue(): String = when (this) {
        ExecutionStatus.SUCCESS -> "SUCCESS"
        ExecutionStatus.FAILED -> "FAILED"
        ExecutionStatus.CANCELLED_DEVICE_OFFLINE -> "CANCELLED_DEVICE_OFFLINE"
        ExecutionStatus.CANCELLED_USER -> "CANCELLED_USER"
    }
}

data class ProgressPayload(
    val executionId: String,
    val eventType: String,
    val stepIndex: Int,
    val stepName: String,
    val status: String,
    val timestamp: String
)

data class LogPayload(
    val executionId: String,
    val eventType: String,
    val level: String,
    val message: String,
    val timestamp: String
)

data class AttachmentPayload(
    val executionId: String,
    val eventType: String,
    val attachmentId: String,
    val type: String,
    val fileName: String,
    val contentType: String,
    val data: String?,
    val downloadUrl: String?,
    val timestamp: String
)

data class ResultPayload(
    val executionId: String,
    val status: String,
    val summary: String,
    val durationMs: Long?,
    val error: ResultError?,
    val outputs: Map<String, Any?>
)

data class ResultError(
    val code: String,
    val message: String,
    val details: Map<String, Any?>
)
