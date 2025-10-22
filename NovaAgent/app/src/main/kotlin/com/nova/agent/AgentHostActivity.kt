package com.nova.agent

import android.app.Activity
import android.os.Bundle
import android.util.Log

class AgentHostActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "AgentHostActivity launched")
        // No UI; this activity keeps the process alive while instrumentation runs.
    }

    companion object {
        private const val TAG = "AgentHostActivity"
    }
}
