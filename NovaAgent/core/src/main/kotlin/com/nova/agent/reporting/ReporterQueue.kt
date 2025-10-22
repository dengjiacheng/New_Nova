package com.nova.agent.reporting

import java.time.Instant

data class ReporterIdentity(
    val tenantId: String,
    val userId: String,
    val pcId: String,
    val deviceId: String
) {
    fun matches(other: ReporterIdentity): Boolean =
        tenantId == other.tenantId &&
            userId == other.userId &&
            pcId == other.pcId &&
            deviceId == other.deviceId

    companion object {
        fun from(
            tenantId: String,
            userId: String,
            pcId: String,
            deviceId: String
        ): ReporterIdentity = ReporterIdentity(tenantId, userId, pcId, deviceId)
    }
}

enum class ReporterAckType {
    PROGRESS,
    RESULT
}

data class ReporterMessage(
    val id: String = java.util.UUID.randomUUID().toString(),
    val correlationId: String,
    val executionId: String,
    val ackType: ReporterAckType,
    val json: String,
    val createdAt: Instant = Instant.now()
)

class ReporterQueueFullException(message: String) : RuntimeException(message)

interface ReporterQueue {
    suspend fun enqueue(identity: ReporterIdentity, message: ReporterMessage)
    suspend fun pending(identity: ReporterIdentity, limit: Int = DEFAULT_DRAIN_LIMIT): List<ReporterMessage>
    suspend fun acknowledge(identity: ReporterIdentity, correlationId: String, ackType: ReporterAckType)
    suspend fun purgeNotMatching(identity: ReporterIdentity)
    suspend fun size(identity: ReporterIdentity): Int

    companion object {
        const val DEFAULT_DRAIN_LIMIT = 100
    }
}
