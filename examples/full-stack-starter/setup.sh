#!/usr/bin/env bash
# setup.sh — wire leakguard + oss-twin + oss-security-scan into a public OSS repo.
#
# Run from inside the public repo you want to wire up:
#   curl -fsSL https://raw.githubusercontent.com/creatornader/oss-security-scan/main/examples/full-stack-starter/setup.sh | bash
#
# Or, if you have the oss-security-scan repo cloned locally:
#   bash path/to/oss-security-scan/examples/full-stack-starter/setup.sh
#
# What this does:
#   1. Verifies cwd is a git repo
#   2. Copies the 4 starter files into the cwd
#   3. Prompts for project-specific values (codenames, mirror path)
#   4. Substitutes the REPLACE_ME placeholders
#   5. Installs pre-commit and activates the hooks
#
# What this does NOT do:
#   - Create the private mirror (run `pip install oss-twin && oss-twin init` separately)
#   - Push the changes (review the new files first, commit explicitly)
#   - Install gitleaks/trufflehog/osv-scanner (they run in CI via the workflow)

set -euo pipefail

# ── Preflight ─────────────────────────────────────────────────────────

if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
  echo "setup.sh: not inside a git repository. Run from your repo root." >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

REPO_NAME=$(basename "$REPO_ROOT")
echo "setup.sh: wiring full stack into $REPO_NAME at $REPO_ROOT"
echo

# ── Find the starter files ────────────────────────────────────────────

# Three sources, in order of preference:
#   1. cloned oss-security-scan repo passed as $STARTER_DIR env var
#   2. cloned oss-security-scan repo at ~/repos/oss-security-scan/
#   3. fetched from GitHub raw

STARTER_DIR="${STARTER_DIR:-}"
if [[ -z "$STARTER_DIR" && -d "$HOME/repos/oss-security-scan/examples/full-stack-starter" ]]; then
  STARTER_DIR="$HOME/repos/oss-security-scan/examples/full-stack-starter"
fi

fetch_from_github() {
  local src="$1" dst="$2"
  curl -fsSL "https://raw.githubusercontent.com/creatornader/oss-security-scan/main/examples/full-stack-starter/$src" -o "$dst"
}

copy_file() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    echo "  skip: $dst already exists (delete or rename it first if you want to overwrite)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -n "$STARTER_DIR" ]]; then
    cp "$STARTER_DIR/$src" "$dst"
  else
    fetch_from_github "$src" "$dst"
  fi
  echo "  wrote: $dst"
}

# ── Copy the 4 files ──────────────────────────────────────────────────

echo "step 1/4: copying starter files"
copy_file ".pre-commit-config.yaml" ".pre-commit-config.yaml"
copy_file "leakguard.yaml" "leakguard.yaml"
copy_file ".oss-twin.yaml" ".oss-twin.yaml"
copy_file ".github/workflows/security-scan.yml" ".github/workflows/security-scan.yml"
echo

# ── Prompt for substitutions ──────────────────────────────────────────

echo "step 2/4: filling in project-specific values"
echo "(press Enter to leave a value as REPLACE_ME for now)"
echo

read -rp "  GitHub username/org (for mirror remote, default REPLACE_ME_USERNAME): " GH_USER
read -rp "  Operator username (the one in /Users/<name>/ paths, default REPLACE_ME_OPERATOR_USERNAME): " OP_USER
read -rp "  Other-project codename #1 (or Enter to skip): " CN1
read -rp "  Other-project codename #2 (or Enter to skip): " CN2

substitute() {
  local file="$1" placeholder="$2" value="$3"
  if [[ -z "$value" ]]; then
    return 0
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|$placeholder|$value|g" "$file"
  else
    sed -i "s|$placeholder|$value|g" "$file"
  fi
}

substitute "leakguard.yaml" "REPLACE_ME_OPERATOR_USERNAME" "${OP_USER:-REPLACE_ME_OPERATOR_USERNAME}"
substitute "leakguard.yaml" "REPLACE_ME_OTHER_PROJECT_A" "${CN1:-REPLACE_ME_OTHER_PROJECT_A}"
substitute "leakguard.yaml" "REPLACE_ME_OTHER_PROJECT_B" "${CN2:-REPLACE_ME_OTHER_PROJECT_B}"
substitute ".oss-twin.yaml" "REPLACE_ME_REPO_NAME" "$REPO_NAME"
substitute ".oss-twin.yaml" "REPLACE_ME_USERNAME" "${GH_USER:-REPLACE_ME_USERNAME}"

echo "  substituted placeholders in leakguard.yaml + .oss-twin.yaml"
echo "  remaining REPLACE_ME entries (review + edit manually):"
grep -l REPLACE_ME .pre-commit-config.yaml leakguard.yaml .oss-twin.yaml .github/workflows/security-scan.yml 2>/dev/null | sed 's/^/    /' || echo "    none"
echo

# ── Install pre-commit ────────────────────────────────────────────────

echo "step 3/4: installing pre-commit"
if command -v pre-commit > /dev/null 2>&1; then
  echo "  pre-commit already installed: $(pre-commit --version)"
else
  if command -v pipx > /dev/null 2>&1; then
    echo "  installing via pipx..."
    pipx install pre-commit
  elif command -v pip > /dev/null 2>&1; then
    echo "  installing via pip --user..."
    pip install --user pre-commit
  else
    echo "  pre-commit not installed and neither pipx nor pip found."
    echo "  Install pre-commit manually: https://pre-commit.com/#install"
  fi
fi
echo

# ── Activate hooks ────────────────────────────────────────────────────

echo "step 4/4: activating hooks"
if command -v pre-commit > /dev/null 2>&1; then
  pre-commit install
  echo "  hooks active. Try: pre-commit run --all-files"
else
  echo "  skipped (pre-commit not on PATH)"
fi
echo

# ── Final message ─────────────────────────────────────────────────────

cat <<'EOF'
setup complete.

next steps:
  1. Review the 4 new files (.pre-commit-config.yaml, leakguard.yaml,
     .oss-twin.yaml, .github/workflows/security-scan.yml)
  2. Replace any remaining REPLACE_ME entries with project-specific values
  3. Optionally scaffold the private mirror:
       pip install oss-twin
       oss-twin init
  4. Commit when satisfied:
       git add -A
       git commit -m "chore: wire in leakguard + oss-twin + oss-security-scan"

docs: https://github.com/creatornader/oss-security-scan/tree/main/examples/full-stack-starter
EOF
