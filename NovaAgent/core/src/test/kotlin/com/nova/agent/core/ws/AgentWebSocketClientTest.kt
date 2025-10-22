package com.nova.agent.core.ws

import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.telemetry.HeartbeatResyncCoordinator
import com.nova.agent.execution.catalog.ParameterField
import com.nova.agent.execution.catalog.ParameterFieldType
import com.nova.agent.execution.catalog.ParameterSchema
import com.nova.agent.execution.catalog.ScriptDescriptor
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AgentWebSocketClientTest {

    private fun config() = AgentConfig(
        tenantId = "TEN-001",
        userId = "USR-001",
        pcId = "PC-001",
        deviceId = "device-001",
        serverUrl = "https://example.com",
        deviceToken = "token-123",
        agentVersion = "2.0.0",
        buildNumber = "2001",
        scriptCatalog = listOf(scriptDescriptor()),
        capabilities = emptyMap(),
        wsUrl = "wss://example.com/ws/agent"
    )

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `initial start sends register once`() = runTest(UnconfinedTestDispatcher()) {
        val factory = RecordingWebSocketFactory()
        val registrationProvider = RecordingRegistrationProvider()
        val heartbeatResync = RecordingHeartbeatResync()
        val client = AgentWebSocketClient(
            config = config(),
            webSocketFactory = factory,
            payloadProvider = registrationProvider,
            ackDetector = AckDetectorBuilder.neverAck(),
            registerAckListeners = mutableListOf(heartbeatResync),
            connectionListeners = mutableListOf(),
            inboundListeners = mutableListOf(),
            logger = TestLogger(),
            scope = this,
            reconnectStrategy = ImmediateReconnectStrategy
        )

        client.start()
        advanceUntilIdle()
        val connection = factory.lastConnection
        requireNotNull(connection)

        factory.listener?.onOpen(connection)
        advanceUntilIdle()

        assertEquals(listOf(false), registrationProvider.invocations)
        assertEquals(1, connection.sentMessages.size)
        assertEquals(0, heartbeatResync.flushCount)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `register ack triggers heartbeat flush`() = runTest(UnconfinedTestDispatcher()) {
        val factory = RecordingWebSocketFactory()
        val registrationProvider = RecordingRegistrationProvider()
        val heartbeatResync = RecordingHeartbeatResync()
        val client = AgentWebSocketClient(
            config = config(),
            webSocketFactory = factory,
            payloadProvider = registrationProvider,
            ackDetector = AckDetectorBuilder.containsAck(),
            registerAckListeners = mutableListOf(heartbeatResync),
            connectionListeners = mutableListOf(),
            inboundListeners = mutableListOf(),
            logger = TestLogger(),
            scope = this,
            reconnectStrategy = ImmediateReconnectStrategy
        )

        client.start()
        advanceUntilIdle()
        val connection = factory.lastConnection!!

        factory.listener?.onOpen(connection)
        advanceUntilIdle()

        factory.listener?.onMessage("""{ "type": "REPLY", "topic": "agents.status", "payload": { "event": "REGISTER_ACK" } }""")
        advanceUntilIdle()

        assertEquals(1, heartbeatResync.flushCount)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `reconnect uses reconnect payload`() = runTest(UnconfinedTestDispatcher()) {
        val factory = RecordingWebSocketFactory()
        val registrationProvider = RecordingRegistrationProvider()
        val connectionListener = RecordingConnectionListener()
        val client = AgentWebSocketClient(
            config = config(),
            webSocketFactory = factory,
            payloadProvider = registrationProvider,
            ackDetector = AckDetectorBuilder.neverAck(),
            registerAckListeners = mutableListOf(RecordingHeartbeatResync()),
            connectionListeners = mutableListOf(connectionListener),
            inboundListeners = mutableListOf(),
            logger = TestLogger(),
            scope = this,
            reconnectStrategy = ImmediateReconnectStrategy
        )

        client.start()
        advanceUntilIdle()
        var connection = factory.lastConnection!!
        factory.listener?.onOpen(connection)
        advanceUntilIdle()

        factory.listener?.onClosed(1006, "test")
        advanceUntilIdle()

        connection = factory.lastConnection!!
        factory.listener?.onOpen(connection)
        advanceUntilIdle()

        assertEquals(listOf(false, true), registrationProvider.invocations)
        assertTrue(connection.sentMessages.isNotEmpty())
        assertEquals(1, connectionListener.disconnectedCount)
    }
}

private fun scriptDescriptor(): ScriptDescriptor =
    ScriptDescriptor(
        id = "SCRIPT_A",
        version = "1.0.0",
        parameters = ParameterSchema(
            fields = listOf(
                ParameterField(
                    key = "dummy",
                    type = ParameterFieldType.STRING,
                    label = "Dummy",
                    required = false
                )
            )
        )
    )

private object ImmediateReconnectStrategy : ReconnectDelayStrategy {
    override fun nextDelayMs(attempt: Int): Long = 0
}

private class RecordingRegistrationProvider : RegistrationPayloadProvider {
    val invocations = mutableListOf<Boolean>()
    override fun buildJson(isReconnect: Boolean): String {
        invocations += isReconnect
        return """{"event":"REGISTER","reconnect":$isReconnect}"""
    }

    override fun build(isReconnect: Boolean): AgentEnvelope<AgentRegisterPayload> {
        return AgentEnvelope(
            type = "EVENT",
            topic = "agents.status",
            correlationId = "test",
            timestamp = "2024-01-01T00:00:00Z",
            payload = AgentRegisterPayload(
                tenantId = "TEN",
                userId = "USR",
                pcId = "PC",
                deviceId = "DEV",
                agentVersion = "1",
                buildNumber = "1",
                scriptCatalog = emptyList(),
                capabilities = emptyMap(),
                recentExecutions = emptyList(),
                metricsSnapshot = null
            )
        )
    }
}

private class RecordingHeartbeatResync : HeartbeatResyncCoordinator {
    var flushCount: Int = 0
        private set

    override suspend fun onRegisterAck() {
        flushCount += 1
    }
}

private class RecordingConnectionListener : ConnectionStateListener {
    var disconnectedCount: Int = 0
        private set

    override suspend fun onDisconnected() {
        disconnectedCount += 1
    }
}

private class RecordingWebSocketFactory : WebSocketFactory {
    var listener: WebSocketEventListener? = null
        private set
    var lastConnection: RecordingConnection? = null
        private set

    override fun connect(url: String, listener: WebSocketEventListener): WebSocketConnection {
        this.listener = listener
        val connection = RecordingConnection()
        lastConnection = connection
        return connection
    }
}

private class RecordingConnection : WebSocketConnection {
    val sentMessages = mutableListOf<String>()
    var closed: Boolean = false
        private set

    override fun send(text: String): Boolean {
        sentMessages += text
        return true
    }

    override fun close(code: Int, reason: String) {
        closed = true
    }
}

private class TestLogger : AgentLogger {
    override fun info(message: String) {}
    override fun warn(message: String) {}
    override fun error(message: String, throwable: Throwable?) {}
}

private object AckDetectorBuilder {
    fun neverAck(): RegisterAckDetector = object : RegisterAckDetector {
        override fun isRegisterAck(json: String): Boolean = false
    }

    fun containsAck(): RegisterAckDetector = object : RegisterAckDetector {
        override fun isRegisterAck(json: String): Boolean =
            json.contains("REGISTER_ACK")
    }
}
