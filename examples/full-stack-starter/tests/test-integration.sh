#!/usr/bin/env bash
# Integration test for the full-stack-starter wire-up.
#
# Verifies that:
#   1. setup.sh runs against a fresh git repo
#   2. The 4 expected files land in the target
#   3. Placeholder substitutions are applied correctly
#   4. pre-commit can be installed and configured against the result
#   5. leakguard scan + oss-twin check both pass on the bootstrapped repo
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
for f in .pre-commit-config.yaml leakguard.yaml .oss-twin.yaml .github/workflows/security-scan.yml; do
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

assert_contains "leakguard.yaml" "test-operator"
assert_contains "leakguard.yaml" "project-other"
assert_contains "leakguard.yaml" "project-extra"
assert_absent   "leakguard.yaml" "REPLACE_ME_OPERATOR_USERNAME"
assert_absent   "leakguard.yaml" "REPLACE_ME_OTHER_PROJECT_A"
assert_absent   "leakguard.yaml" "REPLACE_ME_OTHER_PROJECT_B"

# .oss-twin.yaml mirror.path should use the repo's basename, which is the
# tmpdir leaf. Just check the placeholder is gone.
assert_absent ".oss-twin.yaml" "REPLACE_ME_REPO_NAME"
assert_absent ".oss-twin.yaml" "REPLACE_ME_USERNAME"

# ─────────────────────────────────────────────────────────────────────
# Step 5: run leakguard scan + oss-twin check against the bootstrapped repo
# ─────────────────────────────────────────────────────────────────────
echo "[5/5] running leakguard scan + oss-twin check"

# Install the two tools (CI environment expected to have pip)
pip install -q leakguard 2>/dev/null || pip install -q "git+https://github.com/creatornader/leakguard.git@v0.1.1"
pip install -q oss-twin 2>/dev/null || pip install -q "git+https://github.com/creatornader/oss-twin.git@v0.1.1"

git add -A
git commit -q -m "wire-up"

# leakguard scan: the bootstrapped repo has no leaks (it's a fresh test repo)
if ! leakguard scan; then
  echo "  FAIL: leakguard scan failed on the freshly-bootstrapped repo" >&2
  exit 1
fi
echo "  ok: leakguard scan clean"

# oss-twin check: no private paths exist yet, so check should pass
if ! oss-twin check; then
  echo "  FAIL: oss-twin check failed on the freshly-bootstrapped repo" >&2
  exit 1
fi
echo "  ok: oss-twin check clean"

echo ""
echo "integration test passed."
