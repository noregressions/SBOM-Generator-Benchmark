#!/usr/bin/env bash
# cargo-cyclonedx — CycloneDX generator for Rust crates, driven by cargo metadata.
# Install: brew install cargo-cyclonedx   or   cargo install cargo-cyclonedx   |   https://github.com/CycloneDX/cyclonedx-rust-cargo
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cargo-cyclonedx/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/rust"

echo "== 1. Crate-level SBOM for the host target -> JSON (written next to Cargo.toml as <crate>.cdx.json)"
cargo cyclonedx --manifest-path "$PRJ/Cargo.toml" -f json
mv "$PRJ"/*.cdx.json "$OUT/rust.host-target.cdx.json"

echo "== 2. All targets (platform-conditional deps included) -> XML"
cargo cyclonedx --manifest-path "$PRJ/Cargo.toml" -f xml --target all
mv "$PRJ"/*.cdx.xml "$OUT/rust.all-targets.cdx.xml"

echo "== 3. One SBOM per binary target"
cargo cyclonedx --manifest-path "$PRJ/Cargo.toml" -f json --describe binaries
for f in "$PRJ"/*.cdx.json; do mv "$f" "$OUT/rust.bin-$(basename "$f")"; done

for f in "$OUT"/*.json; do printf "%-36s components=%s\n" "$(basename "$f")" "$(jq '.components|length' "$f")"; done
echo "Done. Outputs in $OUT"
