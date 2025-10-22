package com.nova.agent.reporting.events

import com.nova.agent.execution.history.ExecutionStatus

data class ExecutionResultEvent(
    val executionId: String,
    val status: ExecutionStatus,
    val summary: String,
    val durationMs: Long?,
    val error: ExecutionErrorEvent? = null,
    val outputs: Map<String, Any?> = emptyMap()
)

data class ExecutionErrorEvent(
    val code: String,
    val message: String,
    val details: Map<String, Any?> = emptyMap()
)
