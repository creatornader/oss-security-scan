# Changelog

All notable changes to oss-security-scan are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-10-28

### Changed

- OSV-Scanner findings no longer fail the scan workflow. GitHub marks a code scanning setup as failing whenever the run that uploaded its SARIF fails, which showed a "Code scanning configuration error" banner on every caller with open findings. The scan now saves the scanner's exit code as an `osv-scanner-result` artifact and always succeeds once the SARIF is uploaded.

### Added

- `osv-gate.yml` reusable workflow and [`examples/osv-gate.yml`](examples/osv-gate.yml) caller. It runs on `workflow_run` after the scan and fails when OSV-Scanner found vulnerabilities, so CI still goes red without touching code scanning status.

## [0.1.0] - 2026-05-17

### Added

- Initial extraction. Reusable GitHub Actions workflow that runs typos + gitleaks + trufflehog + osv-scanner against a public OSS repo. Replaces ~100-line inline workflows in caller repos with a ~15-line `uses:` declaration.
- Inputs: `gitleaks-version`, `gitleaks-config`, `typos-version`, `trufflehog-extra-args`, `run-typos`, `run-gitleaks`, `run-trufflehog`, `run-osv-scanner`.
- Gitleaks installed directly (not via `gitleaks-action@v2`) for allowlist-semantics correctness on 8.30+ and force-push resilience.
- OSV-Scanner gated behind `run-osv-scanner: false` by default; callers enable on schedule events to control cost.
- All inputs that reach `run:` blocks flow through `env:` vars per the GitHub injection-safe pattern. No `github.event.*` in `run:` blocks.
- Examples: [`minimal.yml`](examples/minimal.yml) (defaults for everything), [`full.yml`](examples/full.yml) (all inputs surfaced).
- Apache 2.0 license.

[0.3.0]: https://github.com/creatornader/oss-security-scan/releases/tag/v0.3.0
[0.1.0]: https://github.com/creatornader/oss-security-scan/releases/tag/v0.1.0
