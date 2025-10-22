package com.nova.agent.reporting

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.serialization.MoshiFactory
import java.io.File
import kotlin.io.path.createTempDirectory
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlinx.coroutines.runBlocking

class PersistentReporterQueueTest {

    private val tempDir: File = createTempDirectory("reporter-queue-test").toFile()
    private val logger = SilentLogger
    private val queue = PersistentReporterQueue(tempDir, MoshiFactory.default(), logger, capacity = 10)
    private val identity = ReporterIdentity.from("TEN", "USR", "PC", "DEV")

    @AfterTest
    fun cleanup() {
        tempDir.deleteRecursively()
    }

    @Test
    fun `enqueue persists messages to disk`() = runBlocking {
        val message = ReporterMessage(
            correlationId = "corr-1",
            executionId = "EXEC-1",
            ackType = ReporterAckType.PROGRESS,
            json = """{"foo":"bar"}"""
        )
        queue.enqueue(identity, message)

        val reloaded = PersistentReporterQueue(tempDir, MoshiFactory.default(), logger, capacity = 10)
        val pending = reloaded.pending(identity)
        assertEquals(1, pending.size)
        assertEquals("corr-1", pending.first().correlationId)
    }

    @Test
    fun `acknowledge removes matching message`() = runBlocking {
        queue.enqueue(
            identity,
            ReporterMessage(
                correlationId = "corr-2",
                executionId = "EXEC-2",
                ackType = ReporterAckType.RESULT,
                json = "{}"
            )
        )
        assertEquals(1, queue.pending(identity).size)

        queue.acknowledge(identity, "corr-2", ReporterAckType.RESULT)
        assertTrue(queue.pending(identity).isEmpty())
    }

    @Test
    fun `purge removes other identities`() = runBlocking {
        val otherIdentity = ReporterIdentity.from("TEN-X", "USR-X", "PC-X", "DEV-X")
        queue.enqueue(
            otherIdentity,
            ReporterMessage(
                correlationId = "corr-3",
                executionId = "EXEC-3",
                ackType = ReporterAckType.PROGRESS,
                json = "{}"
            )
        )
        queue.purgeNotMatching(identity)
        assertTrue(queue.pending(identity).isEmpty())
    }

    private object SilentLogger : AgentLogger {
        override fun info(message: String) {}
        override fun warn(message: String) {}
        override fun error(message: String, throwable: Throwable?) {}
    }
}
