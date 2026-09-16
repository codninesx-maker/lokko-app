// 1. Add these imports at the very top of the file
import com.android.build.gradle.BaseExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21") // Use 2.0.21 for better compatibility
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    project.layout.buildDirectory.set(newBuildDir.dir(project.name))
}

subprojects {
    afterEvaluate {
        // We use 'extensions.findByType' to safely check for the Android block
        val android = project.extensions.findByType(BaseExtension::class.java)
        if (android != null) {
            // Check if namespace is null or blank
            if (android.namespace == null || android.namespace!!.isEmpty()) {
                val generatedNamespace = "dev.flutter.plugins." + project.name.replace("-", ".")
                android.namespace = generatedNamespace
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}