package com.nova.agent.execution

import com.nova.agent.core.command.CommandOutcome
import com.nova.agent.execution.model.ExecutionTask

/**
 * 提供执行指令处理能力的抽象，便于在路由层与测试中替换具体实现。
 */
interface ExecutionCommandHandler {
    suspend fun handleExecute(task: ExecutionTask): CommandOutcome
    suspend fun handleCancel(): CommandOutcome
}
