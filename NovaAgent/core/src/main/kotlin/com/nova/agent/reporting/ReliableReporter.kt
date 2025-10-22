package com.nova.agent.reporting

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.ws.ConnectionStateListener
import com.nova.agent.core.ws.OutboundMessageSender
import com.nova.agent.core.ws.RegisterAckListener
import com.nova.agent.reporting.events.AttachmentEvent
import com.nova.agent.reporting.events.ExecutionResultEvent
import com.nova.agent.reporting.events.LogEvent
import com.nova.agent.reporting.events.ProgressEvent
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ReliableReporter(
    private val identity: ReporterIdentity,
    private val queue: ReporterQueue,
    private val messageFactory: ReporterMessageFactory,
    private val outbound: OutboundMessageSender,
    private val logger: AgentLogger,
    private val drainLimit: Int = ReporterQueue.DEFAULT_DRAIN_LIMIT
) : Reporter, RegisterAckListener, ConnectionStateListener, ReporterAckListener {

    private val mutex = Mutex()
    private var online: Boolean = false
    private val inFlight: MutableMap<String, ReporterMessage> = linkedMapOf()

    override suspend fun sendProgress(event: ProgressEvent) {
        enqueue(messageFactory.progress(event))
    }

    override suspend fun sendLog(event: LogEvent) {
        enqueue(messageFactory.log(event))
    }

    override suspend fun sendAttachment(event: AttachmentEvent) {
        enqueue(messageFactory.attachment(event))
    }

    override suspend fun sendResult(event: ExecutionResultEvent) {
        enqueue(messageFactory.result(event))
    }

    override suspend fun onRegisterAck() {
        mutex.withLock {
            online = true
        }
        flush()
    }

    override suspend fun onDisconnected() {
        mutex.withLock {
            online = false
            inFlight.clear()
        }
    }

    override suspend fun onReporterAck(correlationId: String, ackType: ReporterAckType, executionId: String) {
        mutex.withLock {
            inFlight.remove(correlationId)
            queue.acknowledge(identity, correlationId, ackType)
        }
        flush()
    }

    suspend fun initialize() {
        queue.purgeNotMatching(identity)
    }

    private suspend fun enqueue(message: ReporterMessage) {
        try {
            queue.enqueue(identity, message)
        } catch (ex: ReporterQueueFullException) {
            logger.error("Reporter queue is full for identity $identity", ex)
            throw ReporterDeliveryException("Reporter queue full", ex)
        }
        flush()
    }

    private suspend fun flush() {
        if (!isOnline()) {
            return
        }
        mutex.withLock {
            if (!online) {
                return
            }
            val pending = queue.pending(identity, drainLimit)
            for (message in pending) {
                if (inFlight.containsKey(message.correlationId)) {
                    continue
                }
                val sent = outbound.sendMessage(message.json)
                if (!sent) {
                    logger.warn("Reporter failed to send message; will retry after reconnect correlationId=${message.correlationId}")
                    online = false
                    return
                }
                inFlight[message.correlationId] = message
            }
        }
    }

    private suspend fun isOnline(): Boolean =
        mutex.withLock { online }
}
