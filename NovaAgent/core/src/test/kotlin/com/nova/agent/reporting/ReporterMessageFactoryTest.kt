package com.nova.agent.reporting

import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.reporting.events.ExecutionResultEvent
import com.nova.agent.reporting.events.LogEvent
import com.nova.agent.reporting.events.LogLevel
import com.nova.agent.reporting.events.ProgressEvent
import com.nova.agent.reporting.events.ProgressStatus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ReporterMessageFactoryTest {

    private val factory = ReporterMessageFactory(MoshiFactory.default())

    @Test
    fun `progress message serializes executions progress`() {
        val message = factory.progress(
            ProgressEvent(
                executionId = "EXEC-1",
                stepIndex = 1,
                stepName = "Step",
                status = ProgressStatus.RUNNING
            )
        )
        assertEquals(ReporterAckType.PROGRESS, message.ackType)
        assertTrue(message.json.contains("\"topic\":\"executions.progress\""))
        assertTrue(message.json.contains("\"eventType\":\"STEP\""))
    }

    @Test
    fun `log message serialized as progress envelope`() {
        val message = factory.log(
            LogEvent(
                executionId = "EXEC-2",
                level = LogLevel.INFO,
                message = "hello"
            )
        )
        assertEquals(ReporterAckType.PROGRESS, message.ackType)
        assertTrue(message.json.contains("\"eventType\":\"LOG\""))
    }

    @Test
    fun `result message serializes executions result`() {
        val message = factory.result(
            ExecutionResultEvent(
                executionId = "EXEC-3",
                status = ExecutionStatus.SUCCESS,
                summary = "OK",
                durationMs = 42
            )
        )
        assertEquals(ReporterAckType.RESULT, message.ackType)
        assertTrue(message.json.contains("\"topic\":\"executions.result\""))
        assertTrue(message.json.contains("\"status\":\"SUCCESS\""))
    }
}
