package com.nova.agent.reporting

interface ReporterAckListener {
    suspend fun onReporterAck(correlationId: String, ackType: ReporterAckType, executionId: String)
}
