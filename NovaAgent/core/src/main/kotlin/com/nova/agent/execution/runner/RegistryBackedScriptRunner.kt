package com.nova.agent.execution.runner

import com.nova.agent.core.logger.AgentLogger
import com.nova.agent.execution.catalog.ScriptRegistry
import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.execution.model.ExecutionTask
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.events.ExecutionErrorEvent
import com.nova.agent.reporting.events.ExecutionResultEvent

/**
 * 基于 ScriptRegistry 的脚本执行器，负责匹配脚本定义并处理缺失场景。
 */
class RegistryBackedScriptRunner(
    private val registry: ScriptRegistry,
    private val logger: AgentLogger
) : ScriptRunner {

    override suspend fun run(task: ExecutionTask, reporter: Reporter): ExecutionResultEvent {
        val definition = registry.find(task.scriptId)
        if (definition == null) {
            logger.warn("未找到脚本定义 scriptId=${task.scriptId}")
            return ExecutionResultEvent(
                executionId = task.executionId,
                status = ExecutionStatus.FAILED,
                summary = "SCRIPT_NOT_FOUND",
                durationMs = null,
                error = ExecutionErrorEvent(
                    code = "SCRIPT_NOT_FOUND",
                    message = "Script ${task.scriptId} is not registered on Agent"
                )
            )
        }

        return definition.handler.run(task, reporter)
    }
}
