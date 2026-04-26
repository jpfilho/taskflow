buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Nenhuma dependência aqui, as configurações de plugins estão no settings.gradle.kts
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(rootProject.file("../build"))

subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.get().asFile.resolve(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Configuração para forçar o namespace no msal_flutter caso não esteja definido
// Isso resolve o erro "Namespace not specified" no AGP 8+
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "msal_flutter") {
            val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            android?.let {
                if (it.namespace == null) {
                    it.namespace = "com.microsoft.msal_flutter"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
