package com.nova.agent.execution.history

import com.squareup.moshi.Json
import java.time.Instant

/**
 * Immutable snapshot describing a completed execution, used for reconnect handshakes.
 */
data class ExecutionSnapshot(
    @Json(name = "executionId")
    val executionId: String,
    @Json(name = "status")
    val status: ExecutionStatus,
    @Json(name = "finishedAt")
    val finishedAt: Instant,
    @Json(name = "resultSummary")
    val resultSummary: String?
)

enum class ExecutionStatus {
    SUCCESS,
    FAILED,
    CANCELLED_DEVICE_OFFLINE,
    CANCELLED_USER
}
