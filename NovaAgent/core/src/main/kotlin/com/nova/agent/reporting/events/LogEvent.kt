package com.nova.agent.reporting.events

import java.time.Instant

data class LogEvent(
    val executionId: String,
    val level: LogLevel,
    val message: String,
    val timestamp: Instant = Instant.now()
)

enum class LogLevel {
    INFO,
    WARN,
    ERROR
}
