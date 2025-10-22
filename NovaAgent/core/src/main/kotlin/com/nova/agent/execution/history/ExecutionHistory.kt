package com.nova.agent.execution.history

import java.time.Instant
import java.util.concurrent.ConcurrentLinkedDeque

/**
 * Thread-safe ring buffer that retains recent execution outcomes for reconnect handshakes.
 */
class ExecutionHistory(
    private val capacity: Int = DEFAULT_CAPACITY
){

    private val recentExecutions = ConcurrentLinkedDeque<ExecutionSnapshot>()

    fun record(snapshot: ExecutionSnapshot) {
        recentExecutions.addFirst(snapshot)
        trimOverflow()
    }

    fun record(
        executionId: String,
        status: ExecutionStatus,
        finishedAt: Instant,
        resultSummary: String?
    ) {
        record(
            ExecutionSnapshot(
                executionId = executionId,
                status = status,
                finishedAt = finishedAt,
                resultSummary = resultSummary
            )
        )
    }

    fun latest(limit: Int = capacity): List<ExecutionSnapshot> {
        if (recentExecutions.isEmpty()) {
            return emptyList()
        }
        return recentExecutions
            .asSequence()
            .take(limit)
            .toList()
            .reversed()
    }

    private fun trimOverflow() {
        while (recentExecutions.size > capacity) {
            recentExecutions.removeLast()
        }
    }

    companion object {
        const val DEFAULT_CAPACITY = 5
    }
}
