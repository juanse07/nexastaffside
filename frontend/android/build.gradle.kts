allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Allow overriding build directory with env var to avoid spaces in paths during debug runs
val buildDirOverride = System.getenv("ANDROID_BUILD_DIR")

// Resolve build directory, supporting absolute paths from env var
val resolvedRootBuildDir = if (!buildDirOverride.isNullOrBlank()) {
    // Use absolute path if provided via ANDROID_BUILD_DIR
    layout.projectDirectory.asFile.resolve(buildDirOverride).let { candidate ->
        // If the provided path is absolute, use it directly; otherwise resolve relative to project
        if (java.io.File(buildDirOverride).isAbsolute) java.io.File(buildDirOverride) else candidate
    }
} else {
    // Default to the repo-level build directory
    rootProject.projectDir.resolve("build")
}

// Apply build directory for root and all subprojects
rootProject.layout.buildDirectory.set(resolvedRootBuildDir)

subprojects {
    val subprojectBuildDir = java.io.File(resolvedRootBuildDir, project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
