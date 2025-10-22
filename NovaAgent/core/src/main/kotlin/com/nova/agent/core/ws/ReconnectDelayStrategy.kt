package com.nova.agent.core.ws

import kotlin.math.pow

interface ReconnectDelayStrategy {
    fun nextDelayMs(attempt: Int): Long
}

class ExponentialBackoffStrategy(
    private val initialDelayMs: Long = 1_000,
    private val multiplier: Double = 1.5,
    private val maxDelayMs: Long = 15_000
) : ReconnectDelayStrategy {
    override fun nextDelayMs(attempt: Int): Long {
        val exponent = attempt.coerceAtMost(10)
        val delay = initialDelayMs * multiplier.pow(exponent.toDouble())
        return delay.coerceAtMost(maxDelayMs.toDouble()).toLong()
    }
}
