# syntax=docker/dockerfile:1
# The canonical environment for the evaluator: toolchains to build the test cases plus every SBOM tool, at the versions
# in tools/versions.env. Build it with ./evaluate --rebuild-image (which passes that file as build args); do not edit
# versions here.
ARG PYTHON_IMAGE
ARG NODE_IMAGE
ARG JDK_IMAGE
ARG MAVEN_IMAGE
ARG DOTNET_IMAGE
ARG DOCKER_CLI_IMAGE

FROM ${NODE_IMAGE} AS node
FROM ${JDK_IMAGE} AS jdk
FROM ${MAVEN_IMAGE} AS maven
FROM ${DOTNET_IMAGE} AS dotnet
FROM ${DOCKER_CLI_IMAGE} AS dockercli

FROM ${PYTHON_IMAGE}
ARG TARGETARCH
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq rsync unzip xz-utils libicu76 libatomic1 libmagic1 \
 && rm -rf /var/lib/apt/lists/*

# --- toolchains ---------------------------------------------------------------------------------------------------
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
COPY --from=maven /usr/share/maven /usr/share/maven
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=dotnet /usr/share/dotnet /usr/share/dotnet
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
ENV JAVA_HOME=/opt/java/openjdk \
    MAVEN_HOME=/usr/share/maven \
    DOTNET_ROOT=/usr/share/dotnet \
    DOTNET_ROLL_FORWARD=Major \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/opt/java/openjdk/bin:/usr/share/maven/bin:/usr/share/dotnet:$PATH
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# --- generators -----------------------------------------------------------------------------------------------------
ARG SYFT_VERSION
ARG GRYPE_VERSION
RUN for t in "syft ${SYFT_VERSION}" "grype ${GRYPE_VERSION}"; do set -- $t; \
      curl -fsSL "https://github.com/anchore/$1/releases/download/v$2/$1_$2_linux_${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin "$1"; \
    done

ARG TRIVY_VERSION
RUN case "${TARGETARCH}" in arm64) a=ARM64 ;; amd64) a=64bit ;; esac; \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${a}.tar.gz" | tar -xz -C /usr/local/bin trivy

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

# Microsoft publishes no linux-arm64 binary of sbom-tool, so it is installed as a .NET tool, which runs on both architectures
ARG SBOM_TOOL_VERSION
RUN dotnet tool install --tool-path /opt/dotnet-tools Microsoft.Sbom.DotNetTool --version "${SBOM_TOOL_VERSION}" \
 && ln -s /opt/dotnet-tools/sbom-tool /usr/local/bin/sbom-tool

# --- scoring ----------------------------------------------------------------------------------------------------------
ARG SBOMQS_VERSION
RUN case "${TARGETARCH}" in arm64) a=arm64 ;; amd64) a=x86_64 ;; esac; \
    curl -fsSL "https://github.com/interlynk-io/sbomqs/releases/download/v${SBOMQS_VERSION}/sbomqs_${SBOMQS_VERSION}_Linux_${a}.tar.gz" | tar -xz -C /usr/local/bin sbomqs

ARG CYCLONEDX_CLI_VERSION
RUN case "${TARGETARCH}" in arm64) a=arm64 ;; amd64) a=x64 ;; esac; \
    curl -fsSL -o /usr/local/bin/cyclonedx "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_CLI_VERSION}/cyclonedx-linux-${a}" \
 && chmod +x /usr/local/bin/cyclonedx

# Fail the build, not the evaluation, if a tool does not start
RUN java -version && mvn -v && node -v && npm -v && python3 -V && dotnet --version && docker --version \
 && syft version && grype version && trivy --version && cdxgen --version && cyclonedx-npm --version \
 && cyclonedx-py --version && sbom4python --version && sbom-tool version && bom version \
 && sbomqs version && cyclonedx --version && docker scout version

WORKDIR /work
