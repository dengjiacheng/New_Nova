package com.nova.agent.runtime

import android.app.Instrumentation
import android.content.Context
import android.os.Bundle
import android.util.Log
import com.nova.agent.BuildConfig
import com.nova.agent.core.boot.AgentKernel
import com.nova.agent.core.config.AgentConfig
import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.core.ws.OkHttpWebSocketFactory
import com.nova.agent.execution.catalog.ScriptCatalogProvider
import com.nova.agent.execution.catalog.ScriptRegistry
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import java.io.File

class AgentRuntime(private val instrumentation: Instrumentation) {

    private val logger = AndroidAgentLogger("NovaAgentRuntime")
    private val scriptRegistry = ScriptRegistry()
    private val catalogProvider = ScriptCatalogProvider(scriptRegistry)
    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            })
            .build()
    }
    private val reporterQueueDir: File by lazy {
        instrumentation.targetContext.getDir(REPORTER_QUEUE_DIR, Context.MODE_PRIVATE)
    }

    private var kernel: AgentKernel? = null

    fun start(arguments: Bundle): Boolean {
        val config = buildAgentConfig(arguments) ?: run {
            logger.error("Missing required instrumentation arguments", null)
            instrumentation.finish(ActivityResultCodes.ERROR, Bundle())
            return false
        }

        logger.info("Starting NovaAgent runtime with deviceId=${config.deviceId}")

        val webSocketFactory = OkHttpWebSocketFactory(okHttpClient, logger)
        val kernel = AgentKernel(
            config = config,
            logger = logger,
            scriptRegistry = scriptRegistry,
            webSocketFactory = webSocketFactory,
            queueDir = reporterQueueDir
        )
        this.kernel = kernel
        kernel.start()

        return true
    }

    fun stop() {
        logger.info("Stopping NovaAgent runtime")
        kernel?.stop()
        kernel = null
    }

    private fun buildAgentConfig(arguments: Bundle): AgentConfig? {
        val serverUrl = arguments.getString(ARG_SERVER_URL)
        val wsUrl = arguments.getString(ARG_AGENT_WS)
        val token = arguments.getString(ARG_DEVICE_TOKEN)
        val tenantId = arguments.getString(ARG_TENANT_ID)
        val userId = arguments.getString(ARG_USER_ID)
        val pcId = arguments.getString(ARG_PC_ID)
        val deviceId = arguments.getString(ARG_DEVICE_ID)

        if (serverUrl.isNullOrBlank() || wsUrl.isNullOrBlank() || token.isNullOrBlank() ||
            tenantId.isNullOrBlank() || userId.isNullOrBlank() || pcId.isNullOrBlank() || deviceId.isNullOrBlank()
        ) {
            return null
        }

        val catalog = catalogProvider.buildCatalog()
        val capabilities = mapOf(
            "opencv" to false,
            "ime" to false
        )

        return AgentConfig(
            tenantId = tenantId,
            userId = userId,
            pcId = pcId,
            deviceId = deviceId,
            serverUrl = serverUrl,
            deviceToken = token,
            agentVersion = BuildConfig.VERSION_NAME,
            buildNumber = BuildConfig.VERSION_CODE.toString(),
            scriptCatalog = catalog,
            capabilities = capabilities,
            wsUrl = wsUrl
        )
    }

    private companion object {
        const val ARG_SERVER_URL = "serverUrl"
        const val ARG_AGENT_WS = "agentWs"
        const val ARG_DEVICE_TOKEN = "token"
        const val ARG_TENANT_ID = "tenantId"
        const val ARG_USER_ID = "userId"
        const val ARG_PC_ID = "pcId"
        const val ARG_DEVICE_ID = "deviceId"
        const val REPORTER_QUEUE_DIR = "reporter_queue"

        object ActivityResultCodes {
            const val ERROR = 1
        }
    }
}

private class AndroidAgentLogger(private val tag: String) : AgentLogger {
    override fun info(message: String) {
        Log.i(tag, message)
    }

    override fun warn(message: String) {
        Log.w(tag, message)
    }

    override fun error(message: String, throwable: Throwable?) {
        Log.e(tag, message, throwable)
    }
}
