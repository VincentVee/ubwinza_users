plugins {
    // Android Gradle Plugin (match versions with your Gradle wrapper if needed)
    id("com.android.application") apply false
    // Kotlin Android (match a compatible Kotlin version)
    id("org.jetbrains.kotlin.android") apply false

    // Google services plugin (for Firebase)
    id("com.google.gms.google-services") version "4.4.2" apply false

    // Optional Firebase plugins — only if you’ll use them
    // id("com.google.firebase.crashlytics") version "3.0.2" apply false
    // id("com.google.firebase.firebase-perf") version "1.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
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
