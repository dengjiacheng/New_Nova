package com.nova.agent.core.ws

import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.logger.AgentLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class AgentWebSocketClient(
    private val config: AgentConfig,
    private val webSocketFactory: WebSocketFactory,
    private val payloadProvider: RegistrationPayloadProvider,
    private val ackDetector: RegisterAckDetector,
    private val registerAckListeners: MutableList<RegisterAckListener> = mutableListOf(),
    private val connectionListeners: MutableList<ConnectionStateListener> = mutableListOf(),
    private val inboundListeners: MutableList<InboundMessageListener> = mutableListOf(),
    private val logger: AgentLogger,
    private val scope: CoroutineScope,
    private val reconnectStrategy: ReconnectDelayStrategy = ExponentialBackoffStrategy()
) : OutboundMessageSender {

    private val stateMutex = Mutex()
    private var connection: WebSocketConnection? = null
    private var running: Boolean = false
    private var reconnectAttempt: Int = 0
    private var hasEverConnected: Boolean = false

    private val listener = object : WebSocketEventListener {
        override fun onOpen(connection: WebSocketConnection) {
            scope.launch {
                handleOpen(connection)
            }
        }

        override fun onMessage(text: String) {
            scope.launch {
                handleMessage(text)
            }
        }

        override fun onClosed(code: Int, reason: String) {
            scope.launch {
                handleClosed(code, reason)
            }
        }

        override fun onFailure(t: Throwable) {
            scope.launch {
                handleFailure(t)
            }
        }
    }

    fun start() {
        scope.launch {
            val shouldOpen = stateMutex.withLock {
                if (running) {
                    false
                } else {
                    running = true
                    reconnectAttempt = 0
                    true
                }
            }
            if (shouldOpen) {
                logger.info("Starting Agent WS connection to ${config.wsUrl}")
                openConnection()
            }
        }
    }

    fun stop() {
        scope.launch {
            val existing = stateMutex.withLock {
                running = false
                val current = connection
                connection = null
                current
            }
            existing?.close(WebSocketConnection.NORMAL_CLOSURE_CODE, "Agent stopping")
        }
    }

    private suspend fun openConnection() {
        val shouldAttempt = stateMutex.withLock { running }
        if (!shouldAttempt) {
            return
        }
        runCatching {
            webSocketFactory.connect(config.wsUrl, listener)
        }.onSuccess { socket ->
            stateMutex.withLock {
                connection = socket
            }
        }.onFailure { throwable ->
            logger.error("Failed to establish WS connection", throwable)
            scheduleReconnect()
        }
    }

    private suspend fun handleOpen(connection: WebSocketConnection) {
        val isReconnect = stateMutex.withLock {
            this.connection = connection
            val reconnect = hasEverConnected
            reconnectAttempt = 0
            hasEverConnected = true
            reconnect
        }
        val json = payloadProvider.buildJson(isReconnect)
        if (!connection.send(json)) {
            logger.error("Failed to send REGISTER payload; closing connection")
            connection.close(1011, "REGISTER send failure")
            notifyDisconnected()
            return
        }
        val phase = if (isReconnect) "reconnect" else "initial"
        logger.info("REGISTER payload sent ($phase)")
    }

    private suspend fun handleMessage(text: String) {
        if (ackDetector.isRegisterAck(text)) {
            logger.info("Received REGISTER_ACK; notifying listeners")
            notifyRegisterAck()
        } else {
            notifyInbound(text)
        }
    }

    private suspend fun handleClosed(code: Int, reason: String) {
        val shouldReconnect = stateMutex.withLock {
            connection = null
            running
        }
        if (shouldReconnect) {
            logger.warn("WS closed ($code/$reason); scheduling reconnect")
            notifyDisconnected()
            scheduleReconnect()
        } else {
            logger.info("WS closed ($code/$reason); client stopped")
        }
    }

    private suspend fun handleFailure(t: Throwable) {
        val shouldReconnect = stateMutex.withLock {
            connection = null
            running
        }
        logger.error("WS failure: ${t.message}", t)
        if (shouldReconnect) {
            notifyDisconnected()
            scheduleReconnect()
        }
    }

    override suspend fun sendMessage(text: String): Boolean {
        val socket = stateMutex.withLock { connection }
        return if (socket != null) {
            val sent = socket.send(text)
            if (!sent) {
                logger.warn("Failed to send message over WS; connection send returned false")
            }
            sent
        } else {
            logger.warn("Discarding outbound message because WS connection is not available")
            false
        }
    }

    private fun scheduleReconnect() {
        scope.launch {
            val decision = stateMutex.withLock {
                if (!running) {
                    ReconnectPlan(0L, 0, false)
                } else {
                    reconnectAttempt += 1
                    val attempt = reconnectAttempt
                    val delayMs = reconnectStrategy.nextDelayMs(attempt)
                    ReconnectPlan(delayMs, attempt, true)
                }
            }
            if (!decision.shouldContinue) {
                return@launch
            }
            if (decision.delayMs > 0) {
                logger.info("Reconnecting in ${decision.delayMs}ms (attempt ${decision.attempt})")
                delay(decision.delayMs)
            }
            openConnection()
        }
    }

    private suspend fun notifyRegisterAck() {
        for (listener in registerAckListeners) {
            listener.onRegisterAck()
        }
    }

    private suspend fun notifyDisconnected() {
        for (listener in connectionListeners) {
            listener.onDisconnected()
        }
    }

    private suspend fun notifyInbound(message: String) {
        if (inboundListeners.isEmpty()) {
            return
        }
        for (listener in inboundListeners) {
            listener.onMessage(message)
        }
    }
}

private data class ReconnectPlan(
    val delayMs: Long,
    val attempt: Int,
    val shouldContinue: Boolean
)
