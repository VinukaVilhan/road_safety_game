import com.android.build.gradle.LibraryExtension
import java.io.File

plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires `namespace` for every Android module.
// Some transitive plugins (e.g. older cached packages) may miss it.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            // Keep library modules aligned with app SDK level to avoid
            // resource-linking issues such as android:attr/lStar not found.
            compileSdk = 36
            if (namespace == null || namespace!!.isBlank()) {
                namespace = "fallback.${project.name.replace('-', '_')}"
            }
        }
    }
}

// Temporary compatibility patch for isar_flutter_libs 3.1.0+1 on AGP 8.x.
run {
    val isarBuildGradle = File(
        System.getProperty("user.home"),
        "AppData/Local/Pub/Cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/build.gradle",
    )
    if (isarBuildGradle.exists()) {
        val original = isarBuildGradle.readText()
        val patched = original.replace("compileSdkVersion 30", "compileSdkVersion 36")
        if (patched != original) {
            isarBuildGradle.writeText(patched)
        }
    }

    val manifest = File(
        System.getProperty("user.home"),
        "AppData/Local/Pub/Cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/src/main/AndroidManifest.xml",
    )
    if (manifest.exists()) {
        val original = manifest.readText()
        val patched = original.replace(" package=\"dev.isar.isar_flutter_libs\"", "")
        if (patched != original) {
            manifest.writeText(patched)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
