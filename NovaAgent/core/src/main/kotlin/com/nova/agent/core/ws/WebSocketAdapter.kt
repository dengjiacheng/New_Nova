package com.nova.agent.core.ws

interface WebSocketConnection {
    fun send(text: String): Boolean
    fun close(code: Int = NORMAL_CLOSURE_CODE, reason: String = "")

    companion object {
        const val NORMAL_CLOSURE_CODE = 1000
    }
}

interface WebSocketEventListener {
    fun onOpen(connection: WebSocketConnection)
    fun onMessage(text: String)
    fun onClosed(code: Int, reason: String)
    fun onFailure(t: Throwable)
}

interface WebSocketFactory {
    fun connect(url: String, listener: WebSocketEventListener): WebSocketConnection
}

interface InboundMessageListener {
    suspend fun onMessage(text: String)
}

interface OutboundMessageSender {
    suspend fun sendMessage(text: String): Boolean
}
