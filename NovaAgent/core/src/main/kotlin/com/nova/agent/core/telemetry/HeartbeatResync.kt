package com.nova.agent.core.telemetry

import com.nova.agent.core.ws.RegisterAckListener

/**
 * Contract for components capable of flushing pending heartbeats immediately after reconnect.
 */
interface HeartbeatResyncCoordinator : RegisterAckListener
