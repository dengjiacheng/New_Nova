package com.nova.agent.core.ws

import com.squareup.moshi.Moshi

interface RegisterAckDetector {
    fun isRegisterAck(json: String): Boolean
}

class AgentMessageDecoder(
    moshi: Moshi
): RegisterAckDetector {
    private val adapter = moshi.adapter(RegisterAckEnvelope::class.java)

    override fun isRegisterAck(json: String): Boolean {
        val envelope = runCatching { adapter.fromJson(json) }.getOrNull()
        return envelope?.type == "REPLY" &&
            envelope.topic == "agents.status" &&
            envelope.payload?.event == "REGISTER_ACK"
    }
}

data class RegisterAckEnvelope(
    val version: String? = null,
    val type: String? = null,
    val topic: String? = null,
    val correlationId: String? = null,
    val payload: RegisterAckPayload? = null
)

data class RegisterAckPayload(
    val event: String? = null,
    val serverTime: String? = null
)
