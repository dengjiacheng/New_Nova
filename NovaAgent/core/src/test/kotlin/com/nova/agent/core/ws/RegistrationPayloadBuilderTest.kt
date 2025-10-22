package com.nova.agent.core.ws

import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.core.telemetry.HeartbeatMetrics
import com.nova.agent.core.telemetry.HeartbeatSnapshot
import com.nova.agent.core.telemetry.HeartbeatStateStore
import com.nova.agent.core.telemetry.NetworkQuality
import com.nova.agent.execution.catalog.ParameterField
import com.nova.agent.execution.catalog.ParameterFieldType
import com.nova.agent.execution.catalog.ParameterSchema
import com.nova.agent.execution.catalog.ScriptDescriptor
import com.nova.agent.execution.history.ExecutionHistory
import com.nova.agent.execution.history.ExecutionSnapshot
import com.nova.agent.execution.history.ExecutionStatus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class RegistrationPayloadBuilderTest {

    private val fixedInstant = Instant.parse("2024-06-01T12:00:00Z")
    private val clock = Clock.fixed(fixedInstant, ZoneOffset.UTC)

    private fun builder(
        history: ExecutionHistory,
        heartbeat: HeartbeatStateStore
    ): RegistrationPayloadBuilder {
        val config = AgentConfig(
            tenantId = "TEN-001",
            userId = "USR-001",
            pcId = "PC-001",
            deviceId = "device-123",
            serverUrl = "https://example.com",
            deviceToken = "token-123",
            agentVersion = "2.0.0",
            buildNumber = "2001",
            scriptCatalog = listOf(scriptDescriptor()),
            capabilities = mapOf("opencv" to true),
            wsUrl = "wss://example.com/ws/agent"
        )
        return RegistrationPayloadBuilder(
            config = config,
            executionHistory = history,
            heartbeatStateStore = heartbeat,
            moshi = MoshiFactory.default(),
            clock = clock,
            correlationIdProvider = { "REG-TEST" }
        )
    }

    @Test
    fun `recentExecutions omitted on initial register`() {
        val history = ExecutionHistory()
        val heartbeat = HeartbeatStateStore()
        val builder = builder(history, heartbeat)

        val envelope = builder.build(isReconnect = false)

        assertEquals("agents.status", envelope.topic)
        assertEquals("REG-TEST", envelope.correlationId)
        assertEquals("REGISTER", envelope.payload.event)
        assertEquals(emptyList(), envelope.payload.recentExecutions)
    }

    @Test
    fun `recentExecutions included on reconnect with metrics snapshot`() {
        val history = ExecutionHistory()
        history.record(
            ExecutionSnapshot(
                executionId = "EXEC-1",
                status = ExecutionStatus.SUCCESS,
                finishedAt = fixedInstant.minusSeconds(60),
                resultSummary = "ok"
            )
        )
        history.record(
            ExecutionSnapshot(
                executionId = "EXEC-2",
                status = ExecutionStatus.FAILED,
                finishedAt = fixedInstant.minusSeconds(30),
                resultSummary = "timeout"
            )
        )
        val heartbeat = HeartbeatStateStore()
        heartbeat.update(
            HeartbeatSnapshot(
                metrics = HeartbeatMetrics(
                    cpuLoad = 0.42,
                    memoryMb = 512,
                    network = NetworkQuality(
                        rttMs = 120,
                        packetLoss = 0.01
                    )
                ),
                lastExecution = history.latest().lastOrNull()
            )
        )
        val builder = builder(history, heartbeat)

        val envelope = builder.build(isReconnect = true)

        assertEquals(2, envelope.payload.recentExecutions.size)
        assertEquals("EXEC-2", envelope.payload.recentExecutions.last().executionId)
        val metrics = envelope.payload.metricsSnapshot
        assertNotNull(metrics)
        assertEquals(0.42, metrics.metrics.cpuLoad)
        assertEquals(512, metrics.metrics.memoryMb)
    }
}

private fun scriptDescriptor(): ScriptDescriptor =
    ScriptDescriptor(
        id = "SCRIPT_LOGIN",
        version = "1.2.0",
        parameters = ParameterSchema(
            fields = listOf(
                ParameterField(
                    key = "username",
                    type = ParameterFieldType.STRING,
                    label = "用户名",
                    required = true
                )
            )
        )
    )
