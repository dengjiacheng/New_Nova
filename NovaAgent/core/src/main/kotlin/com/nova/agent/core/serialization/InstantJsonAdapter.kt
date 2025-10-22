package com.nova.agent.core.serialization

import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.JsonReader
import com.squareup.moshi.JsonWriter
import java.io.IOException
import java.time.Instant
import java.time.format.DateTimeParseException

class InstantJsonAdapter : JsonAdapter<Instant>() {
    @Throws(IOException::class)
    override fun fromJson(reader: JsonReader): Instant? {
        val value = reader.nextString()
        return try {
            Instant.parse(value)
        } catch (ex: DateTimeParseException) {
            throw IOException("Invalid Instant value: $value", ex)
        }
    }

    @Throws(IOException::class)
    override fun toJson(writer: JsonWriter, value: Instant?) {
        if (value == null) {
            writer.nullValue()
        } else {
            writer.value(value.toString())
        }
    }
}
