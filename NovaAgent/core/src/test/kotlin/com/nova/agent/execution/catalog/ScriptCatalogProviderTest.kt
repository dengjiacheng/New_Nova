package com.nova.agent.execution.catalog

import com.nova.agent.execution.history.ExecutionStatus
import com.nova.agent.execution.model.ExecutionTask
import com.nova.agent.execution.runner.ScriptRunner
import com.nova.agent.reporting.Reporter
import com.nova.agent.reporting.events.ExecutionResultEvent
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ScriptCatalogProviderTest {

    @Test
    fun `catalog includes checksum and capabilities`() {
        val registry = ScriptRegistry()
        registry.register(
            ScriptDefinition(
                id = "SCRIPT_LOGIN",
                version = "1.2.3",
                handler = NoopRunner,
                schema = ParameterSchema(
                    fields = listOf(
                        ParameterField(
                            key = "username",
                            type = ParameterFieldType.STRING,
                            label = "用户名",
                            required = true
                        )
                    )
                ),
                capabilities = mapOf("requiresOpenCv" to false, "requiresIme" to true)
            )
        )

        val provider = ScriptCatalogProvider(registry)

        val catalog = provider.buildCatalog()

        val descriptor = catalog.single()
        assertEquals("SCRIPT_LOGIN", descriptor.id)
        assertEquals("1.2.3", descriptor.version)
        assertTrue(descriptor.checksum?.startsWith("sha256:") == true)
        assertEquals(2, descriptor.capabilities.size)
        assertEquals(false, descriptor.capabilities["requiresOpenCv"])
        assertEquals(true, descriptor.capabilities["requiresIme"])
        assertEquals(1, descriptor.parameters.fields.size)
    }
}

private object NoopRunner : ScriptRunner {
    override suspend fun run(task: ExecutionTask, reporter: Reporter): ExecutionResultEvent =
        ExecutionResultEvent(
            executionId = task.executionId,
            status = ExecutionStatus.SUCCESS,
            summary = "noop",
            durationMs = 0
        )
}
