plugins {
    application
    // https://github.com/CycloneDX/cyclonedx-gradle-plugin
    id("org.cyclonedx.bom") version "2.3.1"
}

group = "com.example"
version = "1.0.0"

repositories { mavenCentral() }

java { toolchain { languageVersion.set(JavaLanguageVersion.of(17)) } }

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-databind:2.17.2")
    implementation("org.apache.commons:commons-lang3:3.14.0")
    implementation("org.slf4j:slf4j-api:2.0.13")
    runtimeOnly("org.slf4j:slf4j-simple:2.0.13")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
}

application { mainClass.set("com.example.App") }

// Which resolved configurations go into the SBOM. Override from the CLI, e.g.
//   gradle cyclonedxBom -PsbomConfigs=testRuntimeClasspath -PsbomOutput=bom-combined
val sbomConfigs = (findProperty("sbomConfigs") as String?)?.split(",") ?: listOf("runtimeClasspath")
val sbomOutput = (findProperty("sbomOutput") as String?) ?: "bom"

tasks.cyclonedxBom {
    setIncludeConfigs(sbomConfigs)
    setProjectType("application")
    setSchemaVersion("1.6")
    setDestination(project.file("build/reports"))
    setOutputName(sbomOutput)
    setOutputFormat("all")
    setIncludeBomSerialNumber(true)
    setIncludeLicenseText(false)
}
