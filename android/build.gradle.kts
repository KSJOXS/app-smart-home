buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // บรรทัด 7-8:
        classpath("com.android.tools.build:gradle:8.5.0")  // อัปเกรดจาก 8.1.0
        classpath("com.google.gms:google-services:4.4.2")  // อัปเกรดจาก 4.3.15
      
    }
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