package com.nova.agent.execution

import com.nova.agent.core.command.CommandErrorCodes
import com.nova.agent.core.command.CommandOutcome
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.execution.history.ExecutionHistory
import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.execution.model.AgentState
import com.nova.agent.execution.model.ExecutionTask
import com.nova.agent.execution.runner.ScriptRunner
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.events.ExecutionErrorEvent
import com.nova.agent.reporting.events.ExecutionResultEvent
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Clock
import java.time.Duration
import java.time.Instant

/**
 * Coordinates execution commands, enforcing state transitions and handling cancellation semantics.
 */
class ExecutionCoordinator(
    private val runner: ScriptRunner,
    private val reporter: Reporter,
    private val executionHistory: ExecutionHistory,
    private val logger: AgentLogger,
    private val scope: CoroutineScope,
    private val clock: Clock = Clock.systemUTC()
) : ExecutionCommandHandler {

    private val stateMutex = Mutex()
    private var state: AgentState = AgentState.IDLE
    private var activeTask: ActiveTask? = null

    override suspend fun handleExecute(task: ExecutionTask): CommandOutcome {
        val alreadyRunning = stateMutex.withLock {
            if (state != AgentState.IDLE) {
                true
            } else {
                state = AgentState.RUNNING
                val startedAt = clock.instant()
                val job = launchTask(task, startedAt)
                activeTask = ActiveTask(task = task, job = job, startedAt = startedAt)
                false
            }
        }
        return if (alreadyRunning) {
            CommandOutcome.Error(
                code = CommandErrorCodes.TASK_ALREADY_RUNNING,
                message = "Execution is already in progress"
            )
        } else {
            CommandOutcome.Acknowledged
        }
    }

    override suspend fun handleCancel(): CommandOutcome {
        val taskToCancel = stateMutex.withLock {
            if (state != AgentState.RUNNING) {
                null
            } else {
                state = AgentState.STOPPING
                activeTask?.job
            }
        }
        return if (taskToCancel == null) {
            CommandOutcome.Error(
                code = CommandErrorCodes.NO_TASK_RUNNING,
                message = "No running task to cancel"
            )
        } else {
            logger.info("Cancellation requested by server; signalling current execution to stop")
            taskToCancel.cancel(CancellationException("Cancelled by server"))
            CommandOutcome.Acknowledged
        }
    }

    suspend fun currentState(): AgentState = stateMutex.withLock { state }

    private fun launchTask(task: ExecutionTask, startedAt: Instant): Job =
        scope.launch {
            val result = try {
                runner.run(task, reporter)
            } catch (cancel: CancellationException) {
                logger.warn("Execution ${task.executionId} cancelled by server")
                produceCancelledResult(task, startedAt, cancel)
            } catch (t: Throwable) {
                logger.error("Execution ${task.executionId} failed: ${t.message}", t)
                produceFailureResult(task, startedAt, t)
            }

            finalizeTask(result, startedAt)
        }

    private fun produceCancelledResult(
        task: ExecutionTask,
        startedAt: Instant,
        cancel: CancellationException
    ): ExecutionResultEvent {
        return ExecutionResultEvent(
            executionId = task.executionId,
            status = ExecutionStatus.FAILED,
            summary = "Execution cancelled by server",
            durationMs = calculateDuration(startedAt, clock.instant()),
            error = ExecutionErrorEvent(
                code = "CANCELLED_BY_SERVER",
                message = cancel.message ?: "Execution cancelled by server"
            )
        )
    }

    private fun produceFailureResult(
        task: ExecutionTask,
        startedAt: Instant,
        throwable: Throwable
    ): ExecutionResultEvent {
        return ExecutionResultEvent(
            executionId = task.executionId,
            status = ExecutionStatus.FAILED,
            summary = "Execution failed: ${throwable.message ?: "unknown error"}",
            durationMs = calculateDuration(startedAt, clock.instant()),
            error = ExecutionErrorEvent(
                code = CommandErrorCodes.INTERNAL_ERROR,
                message = throwable.message ?: "Internal error"
            )
        )
    }

    private suspend fun finalizeTask(
        result: ExecutionResultEvent,
        startedAt: Instant
    ) {
        val finishedAt = clock.instant()
        val enrichedResult = if (result.durationMs == null) {
            result.copy(durationMs = calculateDuration(startedAt, finishedAt))
        } else {
            result
        }

        reporter.sendResult(enrichedResult)
        executionHistory.record(
            executionId = enrichedResult.executionId,
            status = enrichedResult.status,
            finishedAt = finishedAt,
            resultSummary = enrichedResult.summary
        )

        stateMutex.withLock {
            state = AgentState.IDLE
            activeTask = null
        }
    }

    private fun calculateDuration(startedAt: Instant, finishedAt: Instant): Long =
        Duration.between(startedAt, finishedAt).toMillis().coerceAtLeast(0L)

    private data class ActiveTask(
        val task: ExecutionTask,
        val job: Job,
        val startedAt: Instant
    )
}
