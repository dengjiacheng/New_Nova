package com.nova.agent.reporting.events

import java.time.Instant

data class AttachmentEvent(
    val executionId: String,
    val attachmentId: String,
    val type: AttachmentType,
    val fileName: String,
    val contentType: String,
    val data: String? = null,
    val downloadUrl: String? = null,
    val timestamp: Instant = Instant.now()
)

enum class AttachmentType {
    SCREENSHOT,
    LOG,
    FILE
}
