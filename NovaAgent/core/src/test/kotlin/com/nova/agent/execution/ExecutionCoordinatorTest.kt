package com.nova.agent.execution

import com.nova.agent.core.command.CommandOutcome
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.execution.history.ExecutionHistory
import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.execution.model.AgentState
import com.nova.agent.execution.model.ExecutionTask
import com.nova.agent.execution.runner.ScriptRunner
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.events.ExecutionResultEvent
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

@OptIn(ExperimentalCoroutinesApi::class)
class ExecutionCoordinatorTest {

    private val dispatcher = UnconfinedTestDispatcher()

    private fun coordinator(
        runner: ScriptRunner,
        history: ExecutionHistory = ExecutionHistory(),
        reporter: RecordingReporter = RecordingReporter(),
        clock: Clock = Clock.systemUTC()
    ): Quadruple {
        val logger = NoopLogger()
        val testScope = TestScope(dispatcher)
        val coordinator = ExecutionCoordinator(
            runner = runner,
            reporter = reporter,
            executionHistory = history,
            logger = logger,
            scope = testScope,
            clock = clock
        )
        return Quadruple(coordinator, history, reporter, testScope)
    }

    @Test
    fun `cancel transitions to stopping and emits cancelled result`() = runTest(dispatcher) {
        val runningFlag = MutableStateFlow(false)
        val runner = object : ScriptRunner {
            override suspend fun run(task: ExecutionTask, reporter: Reporter): ExecutionResultEvent {
                runningFlag.value = true
                try {
                    delay(Long.MAX_VALUE)
                } catch (cancel: CancellationException) {
                    throw cancel
                }
                return ExecutionResultEvent(
                    executionId = task.executionId,
                    status = ExecutionStatus.SUCCESS,
                    summary = "finished",
                    durationMs = 1000
                )
            }
        }
        val fixedClock = Clock.fixed(Instant.parse("2024-06-01T12:00:00Z"), ZoneOffset.UTC)
        val (coordinator, history, reporter, scope) = coordinator(
            runner = runner,
            history = ExecutionHistory(),
            clock = fixedClock
        )

        val task = ExecutionTask(
            executionId = "EXEC-1",
            scriptId = "SCRIPT_LOGIN",
            scriptVersion = "1.0.0",
            parameters = emptyMap(),
            timeoutMs = 30_000L
        )

        val executeOutcome = coordinator.handleExecute(task)
        assertIs<CommandOutcome.Acknowledged>(executeOutcome)
        scope.advanceUntilIdle()
        assertTrue(runningFlag.value)
        assertEquals(AgentState.RUNNING, coordinator.currentState())

        val cancelOutcome = coordinator.handleCancel()
        assertIs<CommandOutcome.Acknowledged>(cancelOutcome)
        scope.advanceUntilIdle()

        val result = reporter.results.single()
        assertEquals("EXEC-1", result.executionId)
        assertEquals(ExecutionStatus.FAILED, result.status)
        assertEquals("CANCELLED_BY_SERVER", result.error?.code)

        val snapshot = history.latest().lastOrNull()
        assertEquals("EXEC-1", snapshot?.executionId)
        assertEquals(ExecutionStatus.FAILED, snapshot?.status)
        assertEquals(AgentState.IDLE, coordinator.currentState())
    }

    @Test
    fun `cancel without running task returns error`() = runTest(dispatcher) {
        val runner = ImmediateRunner()
        val (coordinator, _, _, _) = coordinator(runner = runner)

        val outcome = coordinator.handleCancel()
        val error = assertIs<CommandOutcome.Error>(outcome)
        assertEquals("NO_TASK_RUNNING", error.code)
    }
}

private data class Quadruple(
    val coordinator: ExecutionCoordinator,
    val history: ExecutionHistory,
    val reporter: RecordingReporter,
    val scope: TestScope
)

private class ImmediateRunner : ScriptRunner {
    override suspend fun run(task: ExecutionTask, reporter: Reporter): ExecutionResultEvent {
        return ExecutionResultEvent(
            executionId = task.executionId,
            status = ExecutionStatus.SUCCESS,
            summary = "ok",
            durationMs = 0
        )
    }
}

private class RecordingReporter : Reporter {
    val results = mutableListOf<ExecutionResultEvent>()

    override suspend fun sendProgress(event: com.nova.agent.reporting.events.ProgressEvent) {}

    override suspend fun sendLog(event: com.nova.agent.reporting.events.LogEvent) {}

    override suspend fun sendAttachment(event: com.nova.agent.reporting.events.AttachmentEvent) {}

    override suspend fun sendResult(event: ExecutionResultEvent) {
        results += event
    }
}

private class NoopLogger : AgentLogger {
    override fun info(message: String) {}
    override fun warn(message: String) {}
    override fun error(message: String, throwable: Throwable?) {}
}
