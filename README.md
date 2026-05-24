# oss-security-scan

Reusable GitHub Actions workflow that runs **typos + gitleaks + trufflehog + osv-scanner** against a public OSS repo. One `uses:` line in your repo replaces ~100 lines of inline workflow.

Pairs with [`textleaks`](https://github.com/creatornader/textleaks) (narrative-leak detection) and [`oss-twin`](https://github.com/creatornader/oss-twin) (public/private mirror plumbing). All three are slot-fillers in the public OSS prep stack: oss-security-scan owns credentials + CVEs + spelling; textleaks owns narrative content; oss-twin owns structural separation between public + private repos.

## Use

```yaml
# .github/workflows/security-scan.yml in your repo
name: security-scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 9 * * 0'        # Sunday 09:00 UTC: full OSV-Scanner sweep

permissions:
  contents: read
  actions: read
  security-events: write

jobs:
  scan:
    uses: creatornader/oss-security-scan/.github/workflows/oss-security-scan.yml@v0.1.0
    with:
      gitleaks-version: '8.30.1'
      gitleaks-config: '.gitleaks.toml'
      run-osv-scanner: ${{ github.event_name == 'schedule' }}
```

That's it. The reusable workflow runs the four tools in parallel jobs.

## Inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `gitleaks-version` | string | `8.30.1` | gitleaks version to install |
| `gitleaks-config` | string | `.gitleaks.toml` | Path to gitleaks config (relative to repo root). If absent, gitleaks runs with built-in defaults. |
| `typos-version` | string | `v1.46.1` | crate-ci/typos action version tag |
| `trufflehog-extra-args` | string | `--results=verified,unknown` | Extra args for trufflehog |
| `run-typos` | boolean | `true` | Run typos |
| `run-gitleaks` | boolean | `true` | Run gitleaks |
| `run-trufflehog` | boolean | `true` | Run trufflehog |
| `run-osv-scanner` | boolean | `false` | Run OSV-Scanner (set to schedule-only for cost) |

## Why direct osv-scanner install instead of `google/osv-scanner-action`

The upstream `google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.3.8` runs the scan inside a Docker image (`ghcr.io/google/osv-scanner-action:v2.3.8`) that bundles Go 1.26.2 with `GOTOOLCHAIN=local` hardcoded. Any caller whose `go.mod` requires a Go version newer than 1.26.2 hits a `govulncheck: loading packages: err: go: go.mod requires go >= X (running go 1.26.2; GOTOOLCHAIN=local)` error and the scan fails before producing meaningful output (observed in atrib-log-pp-cli on 2026-05-24 after a dep-group bump forced `go 1.26.3`).

Inlining the scanner — `actions/setup-go` from the caller's `go.mod` (or `stable` when none exists), then `go install github.com/google/osv-scanner/v2/cmd/osv-scanner@<pinned>` with `GOTOOLCHAIN=auto` — solves it: govulncheck can transparently fetch whatever toolchain the caller requires. Trade-offs: we lose the upstream container's preinstalled binary (adds ~20s setup time per scheduled run) and the call-style is now a job composition instead of a single `uses:`. Both are acceptable for the ability to scan repos that are ahead of the upstream container's bundled Go.

## Why direct gitleaks install instead of `gitleaks-action@v2`

Two reasons documented inline in the workflow:

1. **Allowlist semantics**: gitleaks-action's bundled binary (8.24.3 as of 2026-05) does not honor `[[allowlists]]` config correctly. 8.30+ fixes it.
2. **Force-push resilience**: gitleaks-action's push-event mode scans `BEFORE^..HEAD` where `BEFORE = github.event.before`. After a force-push that rewrites history, `BEFORE` points to an orphaned commit and the scan fails with "unknown revision." Direct full-tree invocation does not have this problem.

## Examples

- [`examples/minimal.yml`](examples/minimal.yml): bare-minimum caller workflow (defaults for everything)
- [`examples/full.yml`](examples/full.yml): all inputs surfaced
- [`examples/full-stack-starter/`](examples/full-stack-starter/): copy-paste starter for the full 3-tool stack (oss-security-scan + textleaks + oss-twin together)

## Full-stack wire-up

oss-security-scan is one layer of a three-tool stack. For a new public OSS repo, the typical wire-up uses all three:

| Tool | Concern | File(s) |
|---|---|---|
| [**textleaks**](https://github.com/creatornader/textleaks) | Narrative-leak detection (prose patterns, codenames) | `textleaks.yaml` (pin via `.pre-commit-config.yaml`) |
| [**oss-twin**](https://github.com/creatornader/oss-twin) | Structural mirror gate (no private path in public tree) | `.oss-twin.yaml` (pin via `.pre-commit-config.yaml`) |
| **oss-security-scan** (this tool) | typos + gitleaks + trufflehog + osv-scanner in CI | `.github/workflows/security-scan.yml` (calls this reusable workflow) |

Copy [`examples/full-stack-starter/`](examples/full-stack-starter/) into a fresh repo, edit the codename list in `textleaks.yaml`, edit the private paths in `.oss-twin.yaml`, and you have the full stack wired in ~5 minutes.

## Versioning

Tags are SemVer. Pin to a major (`@v0.1.0` until v1, then `@v1`) for stability. Floating to `@main` is supported but not recommended for production repos.

## Roadmap

v0.1.0 is the initial extraction from a production workflow that has been running across multiple repos. Planned:

- **v0.2**: optional Vale prose lint job
- **v0.2**: optional [textleaks](https://github.com/creatornader/textleaks) job (narrative-leak detection)
- **v0.2**: matrix support for multi-OS gitleaks (windows/macOS runners for cross-platform projects)

## License

Apache 2.0. See [LICENSE](LICENSE).
