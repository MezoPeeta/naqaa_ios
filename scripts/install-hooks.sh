#!/usr/bin/env bash
# One-time setup: point git at the versioned hooks in scripts/hooks.
# Run after cloning the repo:  bash scripts/install-hooks.sh

set -euo pipefail

HOOKS_PATH="scripts/hooks"

if [ ! -d "$HOOKS_PATH" ]; then
    echo "error: $HOOKS_PATH not found - run from the repo root" >&2
    exit 1
fi

git config core.hooksPath "$HOOKS_PATH"
echo "Hooks installed: core.hooksPath -> $HOOKS_PATH"
echo
echo "  pre-commit runs:  swiftlint lint  (~seconds, blocks the commit)"
echo "  pre-push runs:    xcodebuild test  (unit tests only, ~minutes)"
echo
echo "Override the test destination with:  TEST_DESTINATION='platform=iOS Simulator,name=...' git push"