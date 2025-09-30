allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Direct Android build outputs to the Flutter project root build/ so Flutter can locate APKs
val flutterProjectRoot: java.io.File = rootProject.projectDir.parentFile
rootProject.layout.buildDirectory.set(java.io.File(flutterProjectRoot, "build"))

subprojects {
    val subprojectBuildDir = java.io.File(flutterProjectRoot, "build/${project.name}")
    project.layout.buildDirectory.set(subprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
