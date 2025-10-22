package com.nova.agent.execution.catalog

import com.nova.agent.core.serialization.MoshiFactory
import okio.ByteString.Companion.encodeUtf8

class ScriptCatalogProvider(
    private val registry: ScriptRegistry,
    private val checksumCalculator: ScriptChecksumCalculator = ScriptChecksumCalculator()
) {
    fun buildCatalog(): List<ScriptDescriptor> =
        registry.all().map { definition ->
            val checksum = checksumCalculator.compute(definition)
            ScriptDescriptor(
                id = definition.id,
                version = definition.version,
                checksum = checksum,
                parameters = definition.schema,
                capabilities = definition.capabilities
            )
        }
}

class ScriptChecksumCalculator(
    private val encoder: ScriptMetadataEncoder = ScriptMetadataEncoder()
) {
    fun compute(definition: ScriptDefinition): String {
        val json = encoder.encode(definition)
        val digest = json.encodeUtf8().sha256()
        return "sha256:${digest.hex()}"
    }
}

class ScriptMetadataEncoder(
    private val moshiFactory: () -> com.squareup.moshi.Moshi = { MoshiFactory.default() }
) {
    private val adapter by lazy {
        moshiFactory().adapter(ScriptMetadata::class.java)
    }

    fun encode(definition: ScriptDefinition): String {
        val metadata = ScriptMetadata(
            id = definition.id,
            version = definition.version,
            schema = definition.schema,
            capabilities = definition.capabilities
        )
        return adapter.toJson(metadata)
    }

    private data class ScriptMetadata(
        val id: String,
        val version: String,
        val schema: ParameterSchema,
        val capabilities: Map<String, Boolean>
    )
}
