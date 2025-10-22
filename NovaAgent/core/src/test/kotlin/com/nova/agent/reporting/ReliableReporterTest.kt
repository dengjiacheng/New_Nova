package com.nova.agent.reporting

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.core.ws.OutboundMessageSender
import com.nova.agent.reporting.events.ProgressEvent
import com.nova.agent.reporting.events.ProgressStatus
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlinx.coroutines.runBlocking

class ReliableReporterTest {

    private val identity = ReporterIdentity.from("TEN", "USR", "PC", "DEV")
    private lateinit var queue: InMemoryQueue
    private lateinit var sender: RecordingSender
    private lateinit var reporter: ReliableReporter

    @BeforeTest
    fun setup() = runBlocking {
        queue = InMemoryQueue()
        sender = RecordingSender()
        reporter = ReliableReporter(
            identity = identity,
            queue = queue,
            messageFactory = ReporterMessageFactory(MoshiFactory.default()) { "corr-fixed" },
            outbound = sender,
            logger = SilentLogger,
            drainLimit = 10
        )
        reporter.initialize()
    }

    @Test
    fun `messages are enqueued and flushed after ack`() = runBlocking {
        reporter.onRegisterAck()

        reporter.sendProgress(
            ProgressEvent(
                executionId = "EXEC-1",
                stepIndex = 1,
                stepName = "Step",
                status = ProgressStatus.RUNNING
            )
        )

        assertEquals(1, sender.messages.size)
        val pending = queue.pending(identity)
        assertEquals(1, pending.size)

        reporter.onReporterAck(pending.first().correlationId, ReporterAckType.PROGRESS, "EXEC-1")

        assertEquals(0, queue.pending(identity).size)
    }

    private class InMemoryQueue : ReporterQueue {
        private val entries = mutableListOf<Pair<ReporterIdentity, ReporterMessage>>()

        override suspend fun enqueue(identity: ReporterIdentity, message: ReporterMessage) {
            entries += identity to message
        }

        override suspend fun pending(identity: ReporterIdentity, limit: Int): List<ReporterMessage> =
            entries.filter { it.first.matches(identity) }
                .sortedBy { it.second.createdAt }
                .map { it.second }
                .take(limit)

        override suspend fun acknowledge(identity: ReporterIdentity, correlationId: String, ackType: ReporterAckType) {
            val iterator = entries.listIterator()
            while (iterator.hasNext()) {
                val (id, message) = iterator.next()
                if (id.matches(identity) && message.correlationId == correlationId && message.ackType == ackType) {
                    iterator.remove()
                    break
                }
            }
        }

        override suspend fun purgeNotMatching(identity: ReporterIdentity) {
            entries.removeAll { !it.first.matches(identity) }
        }

        override suspend fun size(identity: ReporterIdentity): Int =
            entries.count { it.first.matches(identity) }
    }

    private class RecordingSender : OutboundMessageSender {
        val messages = mutableListOf<String>()

        override suspend fun sendMessage(text: String): Boolean {
            messages += text
            return true
        }
    }

    private object SilentLogger : AgentLogger {
        override fun info(message: String) {}
        override fun warn(message: String) {}
        override fun error(message: String, throwable: Throwable?) {}
    }
}
