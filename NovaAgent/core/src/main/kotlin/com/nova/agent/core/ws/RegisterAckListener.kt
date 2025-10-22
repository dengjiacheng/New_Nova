package com.nova.agent.core.ws

interface RegisterAckListener {
    suspend fun onRegisterAck()
}

interface ConnectionStateListener {
    suspend fun onDisconnected()
}
