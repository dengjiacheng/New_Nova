package com.nova.agent.core.ws

import com.nova.agent.core.serialization.MoshiFactory
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AgentMessageDecoderTest {

    private val decoder = AgentMessageDecoder(MoshiFactory.default())

    @Test
    fun `recognises register ack`() {
        val json = """
            {
              "version": "1.0",
              "type": "REPLY",
              "topic": "agents.status",
              "correlationId": "REG-123",
              "payload": { "event": "REGISTER_ACK", "serverTime": "2024-06-01T12:00:05Z" }
            }
        """.trimIndent()

        assertTrue(decoder.isRegisterAck(json))
    }

    @Test
    fun `ignores unrelated messages`() {
        val json = """
            {
              "version": "1.0",
              "type": "EVENT",
              "topic": "executions.progress",
              "payload": { "event": "STEP", "executionId": "EXEC-1" }
            }
        """.trimIndent()

        assertFalse(decoder.isRegisterAck(json))
    }
}
