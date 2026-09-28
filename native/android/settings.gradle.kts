pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        // Every dependency resolves from these two. JitPack was declared but
        // served nothing (j2v8 6.3.4 and androidsvg 1.4 both live on Central);
        // an unused third-party repository is pure supply-chain surface.
        mavenCentral()
    }
}

rootProject.name = "VueNativeAndroid"
include(":VueNativeCore")
include(":app")
