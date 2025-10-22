package com.nova.agent

import android.app.Application
import android.util.Log

class AgentApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "NovaAgent application created")
    }

    companion object {
        private const val TAG = "NovaAgentApp"
    }
}
