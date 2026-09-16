pluginManagement {
    val storage = java.util.Properties()
    val propertiesFile = settingsDir.resolve("local.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { storage.load(it) }
    }

    val flutterSdkPath = storage.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")

    // We resolve the absolute path and force forward slashes for Windows stability
    val flutterToolsPath = file(flutterSdkPath).resolve("packages/flutter_tools/gradle").absolutePath.replace("\\", "/")

    includeBuild(flutterToolsPath)

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false // Use 8.9.1 exactly
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")