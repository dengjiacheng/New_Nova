package com.nova.agent.execution.model

data class ExecutionTask(
    val executionId: String,
    val scriptId: String,
    val scriptVersion: String,
    val parameters: Map<String, Any?>,
    val timeoutMs: Long,
    val options: Map<String, Any?> = emptyMap()
)
