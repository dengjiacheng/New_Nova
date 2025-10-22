package com.nova.agent.execution.command

import com.nova.agent.core.command.CommandOutcome
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.execution.ExecutionCommandHandler
import com.nova.agent.execution.model.ExecutionTask
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AgentMessageRouterTest {

    private val handler = RecordingHandler()
    private val logger = SilentLogger
    private val moshi = MoshiFactory.default()
    private val parser = ExecuteCommandParser(moshi = moshi, logger = logger)
    private val ackSender = RecordingAckSender()
    private val router = AgentMessageRouter(
        moshi = moshi,
        executeCommandParser = parser,
        executionHandler = handler,
        commandAckSender = ackSender,
        logger = logger
    )

    @Test
    fun `execute command delegates to handler`() = runBlocking {
        ackSender.messages.clear()
        router.onMessage(sampleExecuteCommand())
        assertEquals(1, handler.executions.size)
        assertEquals("EXEC-1", handler.executions.first().executionId)
        assertEquals(listOf("ACCEPTED:EXEC-1"), ackSender.messages)
    }

    @Test
    fun `cancel command delegates to handler`() = runBlocking {
        ackSender.messages.clear()
        handler.cancelled = false
        router.onMessage(sampleCancelCommand())
        assertTrue(handler.cancelled)
        assertEquals(listOf("ACCEPTED:EXEC-1"), ackSender.messages)
    }

    private fun sampleExecuteCommand(): String = """
        {
          "version":"1.0",
          "type":"COMMAND",
          "topic":"executions.command",
          "correlationId":"EXEC-1",
          "payload":{
            "command":"EXECUTE",
            "executionId":"EXEC-1",
            "script":{"id":"SCRIPT_LOGIN","version":"1.0.0"},
            "pcId":"PC-1",
            "deviceId":"DEV-1",
            "tenantId":"TEN-1",
            "userId":"USR-1",
            "parameters":{}
          }
        }
    """.trimIndent()

    private fun sampleCancelCommand(): String = """
        {
          "version":"1.0",
          "type":"COMMAND",
          "topic":"executions.command",
          "correlationId":"EXEC-1",
          "payload":{
            "command":"CANCEL",
            "executionId":"EXEC-1"
          }
        }
    """.trimIndent()

    private class RecordingHandler : ExecutionCommandHandler {
        val executions = mutableListOf<ExecutionTask>()
        var cancelled: Boolean = false

        override suspend fun handleExecute(task: ExecutionTask): CommandOutcome {
            executions += task
            return CommandOutcome.Acknowledged
        }

        override suspend fun handleCancel(): CommandOutcome {
            cancelled = true
            return CommandOutcome.Acknowledged
        }
    }

    private object SilentLogger : AgentLogger {
        override fun info(message: String) {}
        override fun warn(message: String) {}
        override fun error(message: String, throwable: Throwable?) {}
    }

    private class RecordingAckSender : CommandAckSender(
        outbound = object : com.nova.agent.core.ws.OutboundMessageSender {
            override suspend fun sendMessage(text: String): Boolean = true
        },
        moshi = MoshiFactory.default(),
        logger = SilentLogger
    ) {
        val messages = mutableListOf<String>()

        override suspend fun sendAccepted(correlationId: String, executionId: String) {
            messages += "ACCEPTED:$executionId"
        }

        override suspend fun sendRejected(correlationId: String, executionId: String, errorCode: String, message: String) {
            messages += "REJECTED:$executionId:$errorCode"
        }
    }
}
