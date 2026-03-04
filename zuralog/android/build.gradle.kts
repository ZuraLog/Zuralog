allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix Kotlin language version 1.6 errors from legacy Flutter plugins under Kotlin 2.x.
// We pin languageVersion/apiVersion to 1.9 for all Kotlin subprojects so that
// plugins compiled at old language levels (posthog_flutter, package_info_plus,
// shared_preferences_android, etc.) compile cleanly without requiring a JDK toolchain.
// We deliberately avoid overriding jvmTarget here — each plugin's own android {}
// block controls that, and mixing targets causes AGP 8.x mismatch errors.
// afterEvaluate ensures our languageVersion override runs after each plugin's configuration.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
                apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
