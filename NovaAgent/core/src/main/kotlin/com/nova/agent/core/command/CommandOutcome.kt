package com.nova.agent.core.command

sealed class CommandOutcome {
    object Acknowledged : CommandOutcome()
    data class Error(val code: String, val message: String) : CommandOutcome()
}

object CommandErrorCodes {
    const val NO_TASK_RUNNING = "NO_TASK_RUNNING"
    const val TASK_ALREADY_RUNNING = "TASK_ALREADY_RUNNING"
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
}
