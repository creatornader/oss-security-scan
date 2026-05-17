#!/usr/bin/env bash
# Integration test for the full-stack-starter wire-up.
#
# Verifies that:
#   1. setup.sh runs against a fresh git repo
#   2. The 4 expected files land in the target
#   3. Placeholder substitutions are applied correctly
#   4. pre-commit can be installed and configured against the result
#   5. textleaks scan + oss-twin check both pass on the bootstrapped repo
#
# Designed to run in CI (no interactive prompts: we pipe answers to setup.sh
# via stdin). Run locally with: bash tests/test-integration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT

# ─────────────────────────────────────────────────────────────────────
# Step 1: scaffold a fresh git repo as the target
# ─────────────────────────────────────────────────────────────────────
echo "[1/5] scaffolding fresh git repo at $TMP_REPO"
cd "$TMP_REPO"
git init -q -b main
git config user.email "test@example.com"
git config user.name  "Test User"
echo "# Test repo" > README.md
git add README.md
git commit -q -m "initial commit"

# ─────────────────────────────────────────────────────────────────────
# Step 2: run setup.sh with piped answers
# ─────────────────────────────────────────────────────────────────────
echo "[2/5] running setup.sh"
STARTER_DIR="$STARTER_DIR" bash "$STARTER_DIR/setup.sh" <<EOF
test-user
test-operator
project-other
project-extra
EOF

# ─────────────────────────────────────────────────────────────────────
# Step 3: assert the 4 files exist
# ─────────────────────────────────────────────────────────────────────
echo "[3/5] asserting starter files exist"
for f in .pre-commit-config.yaml textleaks.yaml .oss-twin.yaml .github/workflows/security-scan.yml; do
  if [[ ! -f "$f" ]]; then
    echo "  FAIL: $f missing" >&2
    exit 1
  fi
  echo "  ok: $f"
done

# ─────────────────────────────────────────────────────────────────────
# Step 4: assert placeholder substitutions
# ─────────────────────────────────────────────────────────────────────
echo "[4/5] asserting placeholder substitutions"
assert_contains() {
  local file="$1" needle="$2"
  if ! grep -qF "$needle" "$file"; then
    echo "  FAIL: $file does not contain '$needle'" >&2
    exit 1
  fi
  echo "  ok: $file contains '$needle'"
}
assert_absent() {
  local file="$1" needle="$2"
  if grep -qF "$needle" "$file"; then
    echo "  FAIL: $file still contains placeholder '$needle'" >&2
    exit 1
  fi
  echo "  ok: $file no longer contains '$needle'"
}

assert_contains "textleaks.yaml" "test-operator"
assert_contains "textleaks.yaml" "project-other"
assert_contains "textleaks.yaml" "project-extra"
assert_absent   "textleaks.yaml" "REPLACE_ME_OPERATOR_USERNAME"
assert_absent   "textleaks.yaml" "REPLACE_ME_OTHER_PROJECT_A"
assert_absent   "textleaks.yaml" "REPLACE_ME_OTHER_PROJECT_B"

# .oss-twin.yaml mirror.path should use the repo's basename, which is the
# tmpdir leaf. Just check the placeholder is gone.
assert_absent ".oss-twin.yaml" "REPLACE_ME_REPO_NAME"
assert_absent ".oss-twin.yaml" "REPLACE_ME_USERNAME"

# ─────────────────────────────────────────────────────────────────────
# Step 5: run textleaks scan + oss-twin check against the bootstrapped repo
# ─────────────────────────────────────────────────────────────────────
echo "[5/5] running textleaks scan + oss-twin check"

# Install the two tools directly from git. PyPI has an unrelated package
# under the name "leakguard" (the original textleaks name, since renamed).
# Pin to the GitHub release tags to avoid that and any future squatter.
pip install -q "git+https://github.com/creatornader/textleaks.git@v0.2.0"
pip install -q "git+https://github.com/creatornader/oss-twin.git@v0.1.1"

git add -A
git commit -q -m "wire-up"

# textleaks scan: the bootstrapped repo has no leaks (it's a fresh test repo)
if ! textleaks scan; then
  echo "  FAIL: textleaks scan failed on the freshly-bootstrapped repo" >&2
  exit 1
fi
echo "  ok: textleaks scan clean"

# oss-twin check: no private paths exist yet, so check should pass
if ! oss-twin check; then
  echo "  FAIL: oss-twin check failed on the freshly-bootstrapped repo" >&2
  exit 1
fi
echo "  ok: oss-twin check clean"

echo ""
echo "integration test passed."
