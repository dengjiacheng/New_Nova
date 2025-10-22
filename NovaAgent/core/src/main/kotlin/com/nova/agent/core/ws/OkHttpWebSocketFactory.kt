package com.nova.agent.core.ws

import com.nova.agent.core.logger.AgentLogger
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.atomic.AtomicBoolean

class OkHttpWebSocketFactory(
    private val client: OkHttpClient,
    private val logger: AgentLogger
) : WebSocketFactory {

    override fun connect(url: String, listener: WebSocketEventListener): WebSocketConnection {
        val request = Request.Builder().url(url).build()
        val connection = OkHttpWebSocketConnection(listener, logger)
        val ws = client.newWebSocket(request, connection)
        connection.attach(ws)
        return connection
    }

    private class OkHttpWebSocketConnection(
        private val listener: WebSocketEventListener,
        private val logger: AgentLogger
    ) : WebSocketListener(), WebSocketConnection {

        private var delegate: WebSocket? = null
        private val closed = AtomicBoolean(false)

        fun attach(webSocket: WebSocket) {
            delegate = webSocket
        }

        override fun onOpen(webSocket: WebSocket, response: Response) {
            listener.onOpen(this)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            listener.onMessage(text)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            closed.set(true)
            listener.onClosed(code, reason)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (closed.compareAndSet(false, true)) {
                logger.error("WS failure: ${t.message}", t)
                listener.onFailure(t)
            }
        }

        override fun send(text: String): Boolean {
            val ws = delegate ?: return false
            return ws.send(text)
        }

        override fun close(code: Int, reason: String) {
            delegate?.close(code, reason)
        }
    }
}
