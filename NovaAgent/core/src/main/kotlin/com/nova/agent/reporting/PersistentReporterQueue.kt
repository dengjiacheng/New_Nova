package com.nova.agent.reporting

import com.nova.agent.core.logger.AgentLogger
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okio.buffer
import okio.source
import okio.sink
import java.io.File
import java.time.Instant

class PersistentReporterQueue(
    private val storageDir: File,
    private val moshi: Moshi,
    private val logger: AgentLogger,
    private val capacity: Int = DEFAULT_CAPACITY
) : ReporterQueue {

    private val mutex = Mutex()
    private val adapter = moshi.adapter<List<Record>>(
        Types.newParameterizedType(
            List::class.java,
            Record::class.java
        )
    )
    private val queueFile = File(storageDir, FILE_NAME)
    private var loaded = false
    private val records: MutableList<Record> = mutableListOf()

    override suspend fun enqueue(identity: ReporterIdentity, message: ReporterMessage) {
        mutex.withLock {
            ensureLoaded()
            if (countLocked(identity) >= capacity) {
                throw ReporterQueueFullException("Reporter queue capacity exceeded for identity $identity")
            }
            records += Record.from(identity, message)
            persistLocked()
        }
    }

    override suspend fun pending(identity: ReporterIdentity, limit: Int): List<ReporterMessage> =
        mutex.withLock {
            ensureLoaded()
            records
                .asSequence()
                .filter { it.matches(identity) }
                .sortedBy { it.createdAt }
                .take(limit)
                .map { it.toMessage() }
                .toList()
        }

    override suspend fun acknowledge(identity: ReporterIdentity, correlationId: String, ackType: ReporterAckType) {
        mutex.withLock {
            ensureLoaded()
            val iterator = records.listIterator()
            var removed = false
            while (iterator.hasNext()) {
                val record = iterator.next()
                if (record.matches(identity) &&
                    record.correlationId == correlationId &&
                    record.ackType == ackType
                ) {
                    iterator.remove()
                    removed = true
                    break
                }
            }
            if (removed) {
                persistLocked()
            } else {
                logger.warn("Ack miss: correlationId=$correlationId ackType=$ackType identity=$identity")
            }
        }
    }

    override suspend fun purgeNotMatching(identity: ReporterIdentity) {
        mutex.withLock {
            ensureLoaded()
            val before = records.size
            records.removeAll { !it.matches(identity) }
            if (records.size != before) {
                persistLocked()
            }
        }
    }

    override suspend fun size(identity: ReporterIdentity): Int =
        mutex.withLock {
            ensureLoaded()
            countLocked(identity)
        }

    private fun countLocked(identity: ReporterIdentity): Int =
        records.count { it.matches(identity) }

    private fun ensureLoaded() {
        if (loaded) return
        storageDir.mkdirs()
        if (!queueFile.exists()) {
            queueFile.createNewFile()
            queueFile.sink().buffer().use { it.writeUtf8("[]") }
        }
        queueFile.source().buffer().use { source ->
            val content = source.readUtf8()
            if (content.isNotBlank()) {
                val parsed = runCatching { adapter.fromJson(content) }.getOrNull() ?: emptyList()
                records.clear()
                records.addAll(parsed)
            }
        }
        loaded = true
    }

    private fun persistLocked() {
        queueFile.sink().buffer().use { sink ->
            sink.writeUtf8(adapter.toJson(records))
        }
    }

    @JsonClass(generateAdapter = true)
    data class Record(
        val id: String,
        val tenantId: String,
        val userId: String,
        val pcId: String,
        val deviceId: String,
        val correlationId: String,
        val executionId: String,
        val ackType: ReporterAckType,
        val json: String,
        val createdAt: String
    ) {
        fun matches(identity: ReporterIdentity): Boolean =
            identity.tenantId == tenantId &&
                identity.userId == userId &&
                identity.pcId == pcId &&
                identity.deviceId == deviceId

        fun toMessage(): ReporterMessage =
            ReporterMessage(
                id = id,
                correlationId = correlationId,
                executionId = executionId,
                ackType = ackType,
                json = json,
                createdAt = Instant.parse(createdAt)
            )

        companion object {
            fun from(identity: ReporterIdentity, message: ReporterMessage): Record =
                Record(
                    id = message.id,
                    tenantId = identity.tenantId,
                    userId = identity.userId,
                    pcId = identity.pcId,
                    deviceId = identity.deviceId,
                    correlationId = message.correlationId,
                    executionId = message.executionId,
                    ackType = message.ackType,
                    json = message.json,
                    createdAt = message.createdAt.toString()
                )
        }
    }

    companion object {
        private const val FILE_NAME = "reporter_queue.json"
        private const val DEFAULT_CAPACITY = 2000
    }
}
