# Full stack starter

Copy-paste setup for wiring **leakguard + oss-twin + oss-security-scan** into a public OSS repo.

## What you get

Drop these four files into your repo root and you have the full stack:

| File | Provides |
|---|---|
| `.pre-commit-config.yaml` | leakguard + oss-twin-check as local pre-commit hooks |
| `leakguard.yaml` | Codename + operator-path patterns leakguard catches (edit for your project) |
| `.oss-twin.yaml` | Private path list + mirror config oss-twin guards (edit for your project) |
| `.github/workflows/security-scan.yml` | typos + gitleaks + trufflehog + osv-scanner in CI via the reusable workflow + a pre-commit job |

## Setup (one-liner)

From the root of the public repo you want to wire up:

```sh
curl -fsSL https://raw.githubusercontent.com/creatornader/oss-security-scan/main/examples/full-stack-starter/setup.sh | bash
```

`setup.sh` copies the 4 starter files into your repo, prompts for your codenames + GitHub username + operator username, substitutes the placeholders, installs `pre-commit`, and activates the hooks. ~30 seconds. Files with remaining `REPLACE_ME` entries are listed at the end for you to edit manually.

## Setup (manual, if you'd rather not pipe curl into bash)

```sh
# 1. Copy the starter files into your repo root
cp -r path/to/oss-security-scan/examples/full-stack-starter/. .

# 2. Edit codenames + operator names in leakguard.yaml
$EDITOR leakguard.yaml      # replace REPLACE_ME entries

# 3. Edit private paths + mirror config in .oss-twin.yaml
$EDITOR .oss-twin.yaml      # set mirror.path + mirror.remote + private_paths

# 4. Install pre-commit + activate the hooks
pip install pre-commit
pre-commit install

# 5. Verify everything wires up
pre-commit run --all-files  # leakguard + oss-twin-check pass locally
```

If you also want the private mirror scaffolded immediately:

```sh
pip install oss-twin
oss-twin init               # creates ../<repo>-internal/ with CLAUDE.md + .gitignore
```

For an existing repo with operator-private prose that the new gates flag, see the [substrate-skip pattern](#substrate-skip-pattern-for-repos-with-existing-prose-linters) below.

## Substrate-skip pattern (for repos with existing prose linters)

`leakguard.yaml` and `.oss-twin.yaml` BOTH contain codename + path strings as scanner config — defining what to catch, not mentioning the projects in narrative prose. If your repo already runs a prose linter (Vale, an LLM-based audit, your own regex grep), that linter will flag the strings in these config files as if they were narrative leaks. Exempt the two files at the linter level:

- **Vale**: in `.vale.ini`, add `[leakguard.yaml] BasedOnStyles =` and same for `.oss-twin.yaml`
- **LLM-based audit**: add `leakguard.yaml` and `.oss-twin.yaml` to your input-skip list
- **Regex grep with pathspec exclusions**: pass `':!leakguard.yaml' ':!.oss-twin.yaml'` to `git diff` / `git ls-files`

If your repo doesn't already have a prose linter, you can skip this section.

## After wire-up

- **Commit + push to a new branch** — the local hooks fire on every commit; CI runs all 4 scanners + the pre-commit job on PRs
- **Mark a file private retroactively**: `oss-twin move docs/handoffs/internal.md` (moves to mirror, removes from public)
- **Update codename list**: edit `leakguard.yaml`, commit; the new patterns catch from the next commit forward
- **Verify clean**: `leakguard scan` and `oss-twin check` both exit 0

## What's NOT in this starter

- `.gitleaks.toml` — gitleaks config. If your repo has test fixtures that look like credentials (pinned public keys, dummy tokens), add allowlist entries
- `_typos.toml` — typos config for project-specific spellings. Optional
- Operator-private prose-lint substrate — out of scope; live separately in a mirror repo
