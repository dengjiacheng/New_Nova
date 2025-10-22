package com.nova.agent.core.serialization

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import java.time.Instant

object MoshiFactory {
    fun default(): Moshi =
        Moshi.Builder()
            .add(Instant::class.java, InstantJsonAdapter())
            .add(KotlinJsonAdapterFactory())
            .build()
}
