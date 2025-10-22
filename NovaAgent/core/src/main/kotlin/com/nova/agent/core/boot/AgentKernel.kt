package com.nova.agent.core.boot

import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.serialization.MoshiFactory
import com.nova.agent.core.telemetry.HeartbeatStateStore
import com.nova.agent.core.ws.AckMessageHandler
import com.nova.agent.core.ws.AgentMessageDecoder
import com.nova.agent.core.ws.AgentWebSocketClient
import com.nova.agent.core.ws.ConnectionStateListener
import com.nova.agent.core.ws.InboundMessageListener
import com.nova.agent.core.ws.RegisterAckListener
import com.nova.agent.core.ws.RegistrationPayloadBuilder
import com.nova.agent.core.ws.WebSocketFactory
import com.nova.agent.execution.ExecutionCoordinator
import com.nova.agent.execution.catalog.ScriptRegistry
import com.nova.agent.execution.command.AgentMessageRouter
import com.nova.agent.execution.command.CommandAckSender
import com.nova.agent.execution.command.ExecuteCommandParser
import com.nova.agent.execution.history.ExecutionHistory
import com.nova.agent.execution.runner.RegistryBackedScriptRunner
import com.nova.agent.reporting.PersistentReporterQueue
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.ReporterIdentity
import com.nova.agent.reporting.ReporterMessageFactory
import com.nova.agent.reporting.ReliableReporter
import com.squareup.moshi.Moshi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.runBlocking
import java.io.File
import java.time.Clock
import java.util.concurrent.Executors
import kotlin.coroutines.CoroutineContext

/**
 * NovaAgent 核心引导器，负责组装运行所需的依赖并驱动 WS 生命周期。
 */
class AgentKernel(
    private val config: AgentConfig,
    private val logger: AgentLogger,
    private val scriptRegistry: ScriptRegistry,
    private val webSocketFactory: WebSocketFactory,
    private val queueDir: File,
    private val moshi: Moshi = MoshiFactory.default(),
    private val clock: Clock = Clock.systemUTC(),
    coroutineContext: CoroutineContext = SupervisorJob() + Dispatchers.IO
) {

    private val scope = CoroutineScope(coroutineContext)
    private val executionDispatcher = Executors.newSingleThreadExecutor().asCoroutineDispatcher()
    private val executionScope = CoroutineScope(SupervisorJob() + executionDispatcher)
    private val executionHistory = ExecutionHistory()
    private val heartbeatStateStore = HeartbeatStateStore()

    private val registerAckListeners: MutableList<RegisterAckListener> = mutableListOf()
    private val connectionListeners: MutableList<ConnectionStateListener> = mutableListOf()
    private val inboundListeners: MutableList<InboundMessageListener> = mutableListOf()

    private val payloadProvider = RegistrationPayloadBuilder(
        config = config,
        executionHistory = executionHistory,
        heartbeatStateStore = heartbeatStateStore,
        moshi = moshi,
        clock = clock
    )
    private val ackDetector = AgentMessageDecoder(moshi)

    private val webSocketClient = AgentWebSocketClient(
        config = config,
        webSocketFactory = webSocketFactory,
        payloadProvider = payloadProvider,
        ackDetector = ackDetector,
        registerAckListeners = registerAckListeners,
        connectionListeners = connectionListeners,
        inboundListeners = inboundListeners,
        logger = logger,
        scope = scope
    )

    private val reporterIdentity = ReporterIdentity.from(
        tenantId = config.tenantId,
        userId = config.userId,
        pcId = config.pcId,
        deviceId = config.deviceId
    )
    private val reporterQueue = PersistentReporterQueue(queueDir, moshi, logger)
    private val reporterMessageFactory = ReporterMessageFactory(moshi, clock)
    private val reliableReporter = ReliableReporter(
        identity = reporterIdentity,
        queue = reporterQueue,
        messageFactory = reporterMessageFactory,
        outbound = webSocketClient,
        logger = logger
    )

    private val scriptRunner = RegistryBackedScriptRunner(scriptRegistry, logger)
    private val executionCoordinator = ExecutionCoordinator(
        runner = scriptRunner,
        reporter = reliableReporter,
        executionHistory = executionHistory,
        logger = logger,
        scope = executionScope,
        clock = clock
    )

    private val executeCommandParser = ExecuteCommandParser(moshi, logger)
    private val commandAckSender = CommandAckSender(webSocketClient, moshi, logger, clock)
    private val messageRouter = AgentMessageRouter(
        moshi = moshi,
        executeCommandParser = executeCommandParser,
        executionHandler = executionCoordinator,
        commandAckSender = commandAckSender,
        logger = logger
    )
    private val ackMessageHandler = AckMessageHandler(moshi, logger, reliableReporter)

    init {
        registerAckListeners += reliableReporter
        connectionListeners += reliableReporter
        inboundListeners += messageRouter
        inboundListeners += ackMessageHandler
    }

    fun start() {
        runBlocking {
            reliableReporter.initialize()
        }
        webSocketClient.start()
    }

    fun stop() {
        webSocketClient.stop()
        scope.cancel()
        executionScope.cancel()
        executionDispatcher.close()
    }

    fun reporter(): Reporter = reliableReporter

    fun executionHistory(): ExecutionHistory = executionHistory

    fun heartbeatStore(): HeartbeatStateStore = heartbeatStateStore
}
