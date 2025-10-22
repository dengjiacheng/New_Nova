package com.nova.agent.core.telemetry

import com.nova.agent.execution.history.ExecutionSnapshot
import com.squareup.moshi.Json
import java.time.Instant
import java.util.concurrent.atomic.AtomicReference

data class HeartbeatMetrics(
    @Json(name = "cpu")
    val cpuLoad: Double,
    @Json(name = "mem")
    val memoryMb: Long,
    @Json(name = "network")
    val network: NetworkQuality? = null
)

data class NetworkQuality(
    @Json(name = "rttMs")
    val rttMs: Long?,
    @Json(name = "packetLoss")
    val packetLoss: Double?
)

data class HeartbeatSnapshot(
    @Json(name = "metrics")
    val metrics: HeartbeatMetrics,
    @Json(name = "lastExecution")
    val lastExecution: ExecutionSnapshot?,
    @Json(name = "capturedAt")
    val capturedAt: Instant = Instant.now()
)

/**
 * Stores the most recent heartbeat snapshot for reuse during reconnect registration.
 */
class HeartbeatStateStore {
    private val latestSnapshot = AtomicReference<HeartbeatSnapshot?>()

    fun update(snapshot: HeartbeatSnapshot) {
        latestSnapshot.set(snapshot)
    }

    fun update(
        metrics: HeartbeatMetrics,
        lastExecution: ExecutionSnapshot?
    ) {
        update(
            HeartbeatSnapshot(
                metrics = metrics,
                lastExecution = lastExecution
            )
        )
    }

    fun latest(): HeartbeatSnapshot? = latestSnapshot.get()
}
