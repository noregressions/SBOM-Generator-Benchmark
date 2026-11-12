# cargo-cyclonedx

**What it is.** The CycloneDX Cargo subcommand for Rust. Driven by `cargo metadata`, so it reflects the exact resolution in `Cargo.lock`.

**Install.** `brew install cargo-cyclonedx` or `cargo install cargo-cyclonedx`
· [github.com/CycloneDX/cyclonedx-rust-cargo](https://github.com/CycloneDX/cyclonedx-rust-cargo) · Apache-2.0 · tested with 0.5.10

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | Crate-level SBOM for the host target, JSON |
| 2 | `--target all`: include platform-conditional dependencies for every target, XML |
| 3 | `--describe binaries`: one SBOM per binary target |

Outputs are written next to `Cargo.toml` as `<crate>.cdx.json`; the script moves them into `output/`.

## What we saw

- 15 components for the host target. `--target all` adds the wasm/Windows-only crates (`wasm-bindgen`, `windows-sys` families) that
  `uuid` and `serde_json` pull in conditionally, which is a good illustration of why "SBOM for which platform?" matters.
- Best NTIA score of all the outputs in our sbomqs comparison (9.1): crates.io metadata gives every crate a licence, author and purl.

## Strengths / limits

- Strengths: precise, licence-rich, target-aware, tiny.
- Limits: Rust only; no SPDX output (convert with cyclonedx-cli or Syft if you need it).
