import com.android.build.gradle.LibraryExtension

// Forçar namespace default para libs sem declaração (ex: msal_flutter)
System.setProperty("android.defaults.namespace", "com.microsoft.msal_flutter")

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

// Fallback de namespace para libs que não declaram (ex: msal_flutter)
gradle.projectsLoaded {
    rootProject.allprojects {
        if (name.contains("msal_flutter")) {
            // tenta definir namespace antes da avaliação completa
            plugins.withId("com.android.library") {
                (extensions.findByName("android") as? LibraryExtension)?.let { androidExt ->
                    if (androidExt.namespace.isNullOrBlank()) {
                        androidExt.namespace = "com.microsoft.msal_flutter"
                        println("⚙️  Definindo namespace para $name -> ${androidExt.namespace}")
                    }
                }
            }
            // fallback: se ainda não tiver namespace, força um ext extra
            extensions.extraProperties.set("android.defaults.namespace", "com.microsoft.msal_flutter")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
