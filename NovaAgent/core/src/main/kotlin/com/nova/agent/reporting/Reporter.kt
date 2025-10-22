package com.nova.agent.reporting

import com.nova.agent.reporting.events.AttachmentEvent
import com.nova.agent.reporting.events.ExecutionResultEvent
import com.nova.agent.reporting.events.LogEvent
import com.nova.agent.reporting.events.ProgressEvent

/**
 * Unified reporting contract used by the execution coordinator to push telemetry back to NovaServer.
 */
interface Reporter {
    suspend fun sendProgress(event: ProgressEvent)
    suspend fun sendLog(event: LogEvent)
    suspend fun sendAttachment(event: AttachmentEvent)
    suspend fun sendResult(event: ExecutionResultEvent)
}
