package com.nova.agent.instrumentation

import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nova.agent.AgentHostActivity
import com.nova.agent.runtime.AgentRuntime

class NovaInstrumentation : Instrumentation() {

    private lateinit var runtime: AgentRuntime

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        Log.i(TAG, "NovaInstrumentation created")
        runtime = AgentRuntime(this)
        Handler(Looper.getMainLooper()).post {
            val started = runtime.start(arguments ?: Bundle())
            if (started) {
                launchHostActivity()
            }
        }
        start()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (this::runtime.isInitialized) {
            runtime.stop()
        }
        Log.i(TAG, "NovaInstrumentation destroyed")
    }

    private fun launchHostActivity() {
        val intent = Intent(targetContext, AgentHostActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        targetContext.startActivity(intent)
    }

    companion object {
        private const val TAG = "NovaInstrumentation"
    }
}
