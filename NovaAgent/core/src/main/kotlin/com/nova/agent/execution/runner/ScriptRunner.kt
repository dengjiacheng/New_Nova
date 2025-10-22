package com.nova.agent.execution.runner

import com.nova.agent.execution.model.ExecutionTask
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.events.ExecutionResultEvent

/**
 * Adapter that executes a single script command and returns the final result envelope.
 * Implementations are expected to honour coroutine cancellation.
 */
interface ScriptRunner {
    suspend fun run(task: ExecutionTask, reporter: Reporter): ExecutionResultEvent
}
