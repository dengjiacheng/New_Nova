package com.nova.agent.execution.command

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.execution.model.ExecutionTask
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import kotlin.text.toLongOrNull
import java.time.Instant

class ExecuteCommandParser(
    private val moshi: Moshi = MoshiFactory.default(),
    private val logger: AgentLogger
) {

    private val envelopeAdapter = moshi.adapter(CommandEnvelope::class.java)

    fun parse(json: String): ParsedExecuteCommand {
        val envelope = runCatching { envelopeAdapter.fromJson(json) }.getOrElse {
            throw ExecutionCommandValidationException("Invalid JSON payload", it)
        } ?: throw ExecutionCommandValidationException("Empty command payload")

        validateEnvelope(envelope)
        val payload = envelope.payload

        val options = payload.options ?: emptyMap()
        val task = ExecutionTask(
            executionId = payload.executionId,
            scriptId = payload.script.id,
            scriptVersion = payload.script.version,
            parameters = payload.parameters,
            timeoutMs = options["timeoutMs"].asLongOrNull() ?: DEFAULT_TIMEOUT_MS,
            options = options
        )

        val metadata = CommandMetadata(
            correlationId = envelope.correlationId,
            receivedAt = Instant.now(),
            pcId = payload.pcId,
            deviceId = payload.deviceId,
            tenantId = payload.tenantId,
            userId = payload.userId
        )

        val assets = payload.assets?.map {
            AssetDescriptor(
                assetId = it.assetId,
                field = it.field,
                fileName = it.fileName,
                contentType = it.contentType,
                downloadUrl = it.downloadUrl!!,
                size = it.size
            )
        } ?: emptyList()

        logger.info(
            "Parsed EXECUTE command: executionId=${payload.executionId}, " +
                "scriptId=${payload.script.id}, assets=${assets.size}"
        )

        return ParsedExecuteCommand(
            task = task,
            metadata = metadata,
            assets = assets
        )
    }

    private fun validateEnvelope(envelope: CommandEnvelope) {
        if (envelope.type != "COMMAND") {
            throw ExecutionCommandValidationException("Unsupported envelope type: ${envelope.type}")
        }
        if (envelope.topic != "executions.command") {
            throw ExecutionCommandValidationException("Unexpected topic: ${envelope.topic}")
        }

        val payload = envelope.payload
        if (payload.command != "EXECUTE") {
            throw ExecutionCommandValidationException("Unsupported command: ${payload.command}")
        }
        requireNonBlank(payload.executionId, "executionId")
        requireNonBlank(payload.script.id, "script.id")
        requireNonBlank(payload.script.version, "script.version")
        requireNonBlank(payload.pcId, "pcId")
        requireNonBlank(payload.deviceId, "deviceId")
        requireNonBlank(payload.tenantId, "tenantId")
        requireNonBlank(payload.userId, "userId")

        payload.assets?.forEachIndexed { index, asset ->
            requireNonBlank(asset.assetId, "assets[$index].assetId")
            requireNonBlank(asset.field, "assets[$index].field")
            requireNonBlank(asset.fileName, "assets[$index].fileName")
            requireNonBlank(asset.contentType, "assets[$index].contentType")
            requireNonBlank(asset.downloadUrl, "assets[$index].downloadUrl")
            if (asset.size != null && asset.size < 0) {
                throw ExecutionCommandValidationException("assets[$index].size must be >= 0")
            }
        }
    }

    private fun requireNonBlank(value: String?, field: String) {
        if (value.isNullOrBlank()) {
            throw ExecutionCommandValidationException("$field must not be blank")
        }
    }

    companion object {
        private const val DEFAULT_TIMEOUT_MS = 60_000L
    }
}

data class ParsedExecuteCommand(
    val task: ExecutionTask,
    val metadata: CommandMetadata,
    val assets: List<AssetDescriptor>
)

data class CommandMetadata(
    val correlationId: String,
    val receivedAt: Instant,
    val pcId: String,
    val deviceId: String,
    val tenantId: String,
    val userId: String
)

data class AssetDescriptor(
    val assetId: String,
    val field: String,
    val fileName: String,
    val contentType: String,
    val downloadUrl: String,
    val size: Long?
)

class ExecutionCommandValidationException(
    message: String,
    cause: Throwable? = null
) : IllegalArgumentException(message, cause)

@JsonClass(generateAdapter = true)
data class CommandEnvelope(
    @Json(name = "version")
    val version: String,
    @Json(name = "type")
    val type: String,
    @Json(name = "topic")
    val topic: String,
    @Json(name = "correlationId")
    val correlationId: String,
    @Json(name = "payload")
    val payload: ExecutePayload
)

@JsonClass(generateAdapter = true)
data class ExecutePayload(
    @Json(name = "command")
    val command: String,
    @Json(name = "executionId")
    val executionId: String,
    @Json(name = "script")
    val script: ScriptSection,
    @Json(name = "pcId")
    val pcId: String,
    @Json(name = "deviceId")
    val deviceId: String,
    @Json(name = "tenantId")
    val tenantId: String,
    @Json(name = "userId")
    val userId: String,
    @Json(name = "parameters")
    val parameters: Map<String, Any?> = emptyMap(),
    @Json(name = "assets")
    val assets: List<AssetSection>? = emptyList(),
    @Json(name = "options")
    val options: Map<String, Any?>? = emptyMap()
)

@JsonClass(generateAdapter = true)
data class ScriptSection(
    @Json(name = "id")
    val id: String,
    @Json(name = "version")
    val version: String
)

@JsonClass(generateAdapter = true)
data class AssetSection(
    @Json(name = "assetId")
    val assetId: String,
    @Json(name = "field")
    val field: String,
    @Json(name = "fileName")
    val fileName: String,
    @Json(name = "contentType")
    val contentType: String,
    @Json(name = "size")
    val size: Long?,
    @Json(name = "downloadUrl")
    val downloadUrl: String?
)

private fun Any?.asLongOrNull(): Long? =
    when (this) {
        is Number -> this.toLong()
        is String -> this.toLongOrNull()
        else -> null
    }
