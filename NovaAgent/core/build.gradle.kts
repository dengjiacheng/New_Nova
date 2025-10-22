plugins {
    kotlin("jvm") version "1.9.23"
}

dependencies {
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    api("com.squareup.moshi:moshi:1.15.0")
    api("com.squareup.moshi:moshi-kotlin:1.15.0")
    api("com.squareup.okio:okio:3.6.0")
    api("com.squareup.okhttp3:okhttp:4.12.0")
    testImplementation(kotlin("test"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
}

kotlin {
    jvmToolchain(21)
}
