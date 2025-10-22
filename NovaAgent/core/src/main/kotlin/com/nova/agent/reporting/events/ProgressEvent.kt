package com.nova.agent.reporting.events

import java.time.Instant

data class ProgressEvent(
    val executionId: String,
    val stepIndex: Int,
    val stepName: String,
    val status: ProgressStatus,
    val timestamp: Instant = Instant.now()
)

enum class ProgressStatus {
    RUNNING,
    SUCCESS,
    FAILED
}
