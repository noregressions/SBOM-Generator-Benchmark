#!/usr/bin/env bash
# jbom (Contrast Security) — Java SBOMs from *built* artifacts or *running JVMs*: scans jars (incl. nested/shaded) and live processes.
# No package manager; downloads the release jar on first run.   |   https://github.com/Contrast-Security-OSS/jbom
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/jbom/output"; mkdir -p "$OUT" "$ROOT/tools/jbom/bin"
JAR="$ROOT/tools/jbom/bin/jbom.jar"

if [ ! -f "$JAR" ]; then
  echo "== 0. Downloading latest jbom release jar"
  URL=$(gh release view --repo Contrast-Security-OSS/jbom --json assets -q '.assets[] | select(.name|endswith(".jar")) | .url' | head -1)
  curl -sSL -o "$JAR" "$URL"
fi

echo "== 1. Scan a directory of jars (the Maven build output)"
java -jar "$JAR" -d "$ROOT/sample-app/java-maven/target" -o "$OUT" 2>&1 | tail -5

echo "== 2. Scan a single jar"
java -jar "$JAR" -f "$ROOT/sample-app/java-gradle/build/libs/sbom-sample-gradle-1.0.0.jar" -o "$OUT" 2>&1 | tail -5

echo "== 3. Attach to a RUNNING JVM and report what is actually loaded (the headline jbom feature)"
java -cp "$ROOT/sample-app/java-maven/target/classes:$(cd "$ROOT/sample-app/java-maven" && mvn -q dependency:build-classpath -Dmdep.outputFile=/dev/stdout)" \
  com.example.App >/dev/null 2>&1 &
PID=$!
sleep 1
java -jar "$JAR" -p "$PID" -o "$OUT" 2>&1 | tail -5 || echo "(attach failed; on macOS you may need the same JDK for target and jbom, or -Djdk.attach.allowAttachSelf)"
kill "$PID" 2>/dev/null || true
ls -la "$OUT"
echo "Done. Outputs in $OUT"
