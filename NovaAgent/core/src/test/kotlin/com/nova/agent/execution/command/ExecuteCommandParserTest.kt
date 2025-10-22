package com.nova.agent.execution.command

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.execution.model.ExecutionTask
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest

@OptIn(ExperimentalCoroutinesApi::class)
class ExecuteCommandParserTest {

    private val logger = CollectingLogger()
    private val parser = ExecuteCommandParser(logger = logger)

    @Test
    fun `parse valid command`() = runTest {
        val json = """
            {
              "version": "1.0",
              "type": "COMMAND",
              "topic": "executions.command",
              "correlationId": "EXEC-1",
              "payload": {
                "command": "EXECUTE",
                "executionId": "EXEC-1",
                "script": { "id": "SCRIPT_LOGIN", "version": "1.2.0" },
                "pcId": "PC-1",
                "deviceId": "DEV-1",
                "tenantId": "TEN-1",
                "userId": "USR-1",
                "parameters": { "username": "demo" },
                "assets": [
                  {
                    "assetId": "AST-1",
                    "field": "image",
                    "fileName": "img.png",
                    "contentType": "image/png",
                    "size": 512,
                    "downloadUrl": "https://example.com/a"
                  }
                ],
                "options": { "timeoutMs": 45000, "retryOnFailure": true }
              }
            }
        """.trimIndent()

        val parsed = parser.parse(json)

        assertEquals("EXEC-1", parsed.task.executionId)
        assertEquals("SCRIPT_LOGIN", parsed.task.scriptId)
        assertEquals(45_000L, parsed.task.timeoutMs)
        assertEquals(1, parsed.assets.size)
        assertEquals("AST-1", parsed.assets.first().assetId)
    }

    @Test
    fun `missing asset url raises validation error`() {
        val json = """
            {
              "version": "1.0",
              "type": "COMMAND",
              "topic": "executions.command",
              "correlationId": "EXEC-2",
              "payload": {
                "command": "EXECUTE",
                "executionId": "EXEC-2",
                "script": { "id": "SCRIPT_LOGIN", "version": "1.2.0" },
                "pcId": "PC-1",
                "deviceId": "DEV-1",
                "tenantId": "TEN-1",
                "userId": "USR-1",
                "assets": [
                  {
                    "assetId": "AST-1",
                    "field": "image",
                    "fileName": "img.png",
                    "contentType": "image/png",
                    "size": 512
                  }
                ]
              }
            }
        """.trimIndent()

        val ex = assertFailsWith<ExecutionCommandValidationException> {
            parser.parse(json)
        }
        assertTrue(ex.message?.contains("assets[0].downloadUrl") == true)
    }

    @Test
    fun `non numeric timeout falls back to default`() {
        val json = """
            {
              "version": "1.0",
              "type": "COMMAND",
              "topic": "executions.command",
              "correlationId": "EXEC-3",
              "payload": {
                "command": "EXECUTE",
                "executionId": "EXEC-3",
                "script": { "id": "SCRIPT_LOGIN", "version": "1.2.0" },
                "pcId": "PC-1",
                "deviceId": "DEV-1",
                "tenantId": "TEN-1",
                "userId": "USR-1",
                "options": { "timeoutMs": "invalid" }
              }
            }
        """.trimIndent()

        val parsed = parser.parse(json)

        assertEquals(60_000L, parsed.task.timeoutMs)
    }
}

private class CollectingLogger : AgentLogger {
    override fun info(message: String) {}
    override fun warn(message: String) {}
    override fun error(message: String, throwable: Throwable?) {}
}
