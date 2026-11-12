# syntax=docker/dockerfile:1
# The canonical environment for the SBOM Generator Benchmark: toolchains to build the test cases plus every SBOM tool,
# each downloaded from its own publisher at the version in tools/versions.env. Build it with `make image`, which
# passes that file as build args; do not edit versions here.
#
# Python comes from the base image. Everything else is a pinned download, in the order: toolchains, generators, scoring.
ARG PYTHON_IMAGE
FROM ${PYTHON_IMAGE}
ARG TARGETARCH
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq rsync unzip xz-utils libicu76 libatomic1 libmagic1 \
 && rm -rf /var/lib/apt/lists/*

# Publishers spell the two architectures differently (arm64/aarch64/ARM64, amd64/x64/x86_64/64bit). The spellings are
# written down once here; each step below sources the file and uses the one its publisher wants.
RUN case "${TARGETARCH}" in \
      arm64) printf 'A_X64=arm64\nA_UNAME=aarch64\nA_JDK=aarch64\nA_TRIVY=ARM64\nA_SBOMQS=arm64\n' ;; \
      amd64) printf 'A_X64=x64\nA_UNAME=x86_64\nA_JDK=x64\nA_TRIVY=64bit\nA_SBOMQS=x86_64\n' ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac > /etc/arch.env

# --- toolchains -------------------------------------------------------------------------------------------------------
ARG JDK_VERSION
RUN . /etc/arch.env; mkdir -p /opt/java \
 && curl -fsSL "https://github.com/adoptium/temurin${JDK_VERSION%%.*}-binaries/releases/download/jdk-${JDK_VERSION/+/%2B}/OpenJDK${JDK_VERSION%%.*}U-jdk_${A_JDK}_linux_hotspot_${JDK_VERSION/+/_}.tar.gz" \
    | tar -xz -C /opt/java --strip-components=1

ARG MAVEN_VERSION
RUN mkdir -p /opt/maven \
 && curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | tar -xz -C /opt/maven --strip-components=1

ARG NODE_VERSION
RUN . /etc/arch.env; mkdir -p /opt/node \
 && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${A_X64}.tar.xz" | tar -xJ -C /opt/node --strip-components=1

# .NET is here for one tool: Microsoft publishes no linux-arm64 binary of sbom-tool, so it is installed as a .NET tool
ARG DOTNET_SDK_VERSION
RUN . /etc/arch.env; mkdir -p /opt/dotnet \
 && curl -fsSL "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-${A_X64}.tar.gz" | tar -xz -C /opt/dotnet

# The Docker client only: the image stage talks to the host's daemon through the mounted socket
ARG DOCKER_CLI_VERSION
ARG DOCKER_BUILDX_VERSION
RUN . /etc/arch.env; mkdir -p /usr/local/libexec/docker/cli-plugins \
 && curl -fsSL "https://download.docker.com/linux/static/stable/${A_UNAME}/docker-${DOCKER_CLI_VERSION}.tgz" | tar -xz -C /usr/local/bin --strip-components=1 docker/docker \
 && curl -fsSL -o /usr/local/libexec/docker/cli-plugins/docker-buildx "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${TARGETARCH}" \
 && chmod +x /usr/local/libexec/docker/cli-plugins/docker-buildx

ENV JAVA_HOME=/opt/java \
    MAVEN_HOME=/opt/maven \
    DOTNET_ROOT=/opt/dotnet \
    DOTNET_ROLL_FORWARD=Major \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/opt/java/bin:/opt/maven/bin:/opt/node/bin:/opt/dotnet:$PATH

# --- generators -------------------------------------------------------------------------------------------------------
ARG SYFT_VERSION
RUN curl -fsSL "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin syft

ARG TRIVY_VERSION
RUN . /etc/arch.env \
 && curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${A_TRIVY}.tar.gz" | tar -xz -C /usr/local/bin trivy

ARG BOM_VERSION
RUN curl -fsSL -o /usr/local/bin/bom "https://github.com/kubernetes-sigs/bom/releases/download/v${BOM_VERSION}/bom-${TARGETARCH}-linux" \
 && chmod +x /usr/local/bin/bom

ARG DOCKER_SCOUT_VERSION
RUN curl -fsSL "https://github.com/docker/scout-cli/releases/download/v${DOCKER_SCOUT_VERSION}/docker-scout_${DOCKER_SCOUT_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /usr/local/libexec/docker/cli-plugins docker-scout

ARG CDXGEN_VERSION
ARG CYCLONEDX_NPM_VERSION
RUN npm install -g --no-audit --no-fund "@cyclonedx/cdxgen@${CDXGEN_VERSION}" "@cyclonedx/cyclonedx-npm@${CYCLONEDX_NPM_VERSION}" \
 && npm cache clean --force

ARG CYCLONEDX_PY_VERSION
ARG SBOM4PYTHON_VERSION
RUN pip install --no-cache-dir "cyclonedx-bom==${CYCLONEDX_PY_VERSION}" "sbom4python==${SBOM4PYTHON_VERSION}"

ARG SBOM_TOOL_VERSION
RUN dotnet tool install --tool-path /opt/dotnet-tools Microsoft.Sbom.DotNetTool --version "${SBOM_TOOL_VERSION}" \
 && ln -s /opt/dotnet-tools/sbom-tool /usr/local/bin/sbom-tool

# --- scoring and consumers --------------------------------------------------------------------------------------------
ARG SBOMQS_VERSION
RUN . /etc/arch.env \
 && curl -fsSL "https://github.com/interlynk-io/sbomqs/releases/download/v${SBOMQS_VERSION}/sbomqs_${SBOMQS_VERSION}_Linux_${A_SBOMQS}.tar.gz" | tar -xz -C /usr/local/bin sbomqs

ARG CYCLONEDX_CLI_VERSION
RUN . /etc/arch.env \
 && curl -fsSL -o /usr/local/bin/cyclonedx "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_CLI_VERSION}/cyclonedx-linux-${A_X64}" \
 && chmod +x /usr/local/bin/cyclonedx

ARG GRYPE_VERSION
RUN curl -fsSL "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin grype

# Fail the build, not the benchmark, if a tool does not start
RUN java -version && mvn -v && node -v && npm -v && python3 -V && dotnet --version && docker --version && docker buildx version \
 && syft version && grype version && trivy --version && cdxgen --version && cyclonedx-npm --version \
 && cyclonedx-py --version && sbom4python --version && sbom-tool version && bom version \
 && sbomqs version && cyclonedx --version && docker scout version

WORKDIR /work
