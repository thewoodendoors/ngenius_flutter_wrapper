group = "com.thewoodendoors.ngenius_flutter_wrapper"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The N-Genius Android SDK is published through JitPack only. The host app resolves it as a
// transitive dependency of this module, so the repository has to be visible to every project of
// the build, not just this one. (A host settings.gradle that uses
// dependencyResolutionManagement with FAIL_ON_PROJECT_REPOS must add it there instead.)
rootProject.allprojects {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.thewoodendoors.ngenius_flutter_wrapper"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("proguard-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // N-Genius Online Android SDK (github.com/network-international/payment-sdk-android), pinned to
    // the newest tag that builds green on JitPack.
    implementation("com.github.network-international.payment-sdk-android:payment-sdk-core:5.2.7")
    implementation("com.github.network-international.payment-sdk-android:payment-sdk:5.2.7")

    // The SDK's own dependencies are runtime-scoped in its POM; the ones this plugin compiles
    // against are declared explicitly.
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("com.google.android.gms:play-services-wallet:19.4.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
