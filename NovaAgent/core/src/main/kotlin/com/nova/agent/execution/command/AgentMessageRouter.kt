package com.nova.agent.execution.command

import com.nova.agent.core.command.CommandOutcome
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.ws.InboundMessageListener
import com.nova.agent.execution.ExecutionCommandHandler
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi

/**
 * 将 WS 下行消息分发到对应的执行协调逻辑，目前聚焦 EXECUTE/CANCEL 指令。
 */
class AgentMessageRouter(
    private val moshi: Moshi,
    private val executeCommandParser: ExecuteCommandParser,
    private val executionHandler: ExecutionCommandHandler,
    private val commandAckSender: CommandAckSender,
    private val logger: AgentLogger
) : InboundMessageListener {

    private val previewAdapter = moshi.adapter(CommandPreview::class.java)

    override suspend fun onMessage(text: String) {
        val preview = runCatching { previewAdapter.fromJson(text) }.getOrElse { error ->
            logger.warn("忽略无法解析的 WS 消息: ${error.message}")
            return
        } ?: return

        when {
            preview.isExecuteCommand() -> handleExecute(text, preview.correlationId)
            preview.isCancelCommand() -> handleCancel(preview.payload?.executionId, preview.correlationId)
            else -> logger.info("跳过非执行类消息 topic=${preview.topic} type=${preview.type}")
        }
    }

    private suspend fun handleExecute(raw: String, correlationId: String?) {
        val parsed = runCatching { executeCommandParser.parse(raw) }.getOrElse { error ->
            logger.warn("EXECUTE 指令解析失败: ${error.message}")
            correlationId?.let {
                commandAckSender.sendRejected(
                    correlationId = it,
                    executionId = "",
                    errorCode = "INVALID_PAYLOAD",
                    message = error.message ?: "Invalid EXECUTE payload"
                )
            }
            return
        }

        when (val outcome = executionHandler.handleExecute(parsed.task)) {
            is CommandOutcome.Acknowledged -> {
                logger.info("已接受执行任务 ${parsed.task.executionId}")
                correlationId?.let {
                    commandAckSender.sendAccepted(it, parsed.task.executionId)
                }
            }
            is CommandOutcome.Error -> logger.warn(
                "执行任务被拒绝 executionId=${parsed.task.executionId} code=${outcome.code} msg=${outcome.message}"
            ).also {
                correlationId?.let {
                    commandAckSender.sendRejected(
                        correlationId = it,
                        executionId = parsed.task.executionId,
                        errorCode = outcome.code,
                        message = outcome.message
                    )
                }
            }
        }
    }

    private suspend fun handleCancel(executionId: String?, correlationId: String?) {
        val outcome = executionHandler.handleCancel()
        if (outcome is CommandOutcome.Error) {
            logger.warn("CANCEL 指令被拒绝 executionId=${executionId ?: "unknown"} code=${outcome.code}")
            correlationId?.let {
                commandAckSender.sendRejected(
                    correlationId = it,
                    executionId = executionId ?: "",
                    errorCode = outcome.code,
                    message = outcome.message
                )
            }
        } else {
            logger.info("已受理 CANCEL 指令 executionId=${executionId ?: "unknown"}")
            correlationId?.let {
                commandAckSender.sendAccepted(
                    correlationId = it,
                    executionId = executionId ?: ""
                )
            }
        }
    }

    @JsonClass(generateAdapter = true)
    data class CommandPreview(
        @Json(name = "type")
        val type: String?,
        @Json(name = "topic")
        val topic: String?,
        @Json(name = "correlationId")
        val correlationId: String?,
        @Json(name = "payload")
        val payload: CommandPreviewPayload?
    ) {
        fun isExecuteCommand(): Boolean =
            type == "COMMAND" &&
                topic == "executions.command" &&
                payload?.command == "EXECUTE"

        fun isCancelCommand(): Boolean =
            type == "COMMAND" &&
                topic == "executions.command" &&
                payload?.command == "CANCEL"
    }

    @JsonClass(generateAdapter = true)
    data class CommandPreviewPayload(
        @Json(name = "command")
        val command: String?,
        @Json(name = "executionId")
        val executionId: String?
    )
}
