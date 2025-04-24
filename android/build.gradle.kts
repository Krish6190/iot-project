// This should be inside the buildscript block, not allprojects block
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.0.4")
        classpath("com.google.gms:google-services:4.3.10")
    }
}

// This block is fine as is for defining the build directories
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task definition - no changes needed
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
