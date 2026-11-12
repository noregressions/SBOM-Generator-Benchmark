plugins {
    // lets Gradle download a JDK 17 toolchain when none is installed (e.g. inside the ORT container)
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
rootProject.name = "sbom-sample-gradle"
