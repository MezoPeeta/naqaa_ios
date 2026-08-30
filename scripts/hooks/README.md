# Git hooks

These hooks live in the repo (via `git config core.hooksPath`) so they're shared
and versioned instead of sitting in each developer's `.git/hooks`.

## Install (once per clone)

```sh
bash scripts/install-hooks.sh
```

## What they do

| Hook | When | Runs | Cost |
|---|---|---|---|
| `pre-commit` | every `git commit` | `swiftlint lint` | ~2 seconds |
| `pre-push` | every `git push` | `xcodebuild test -scheme naqaa -only-testing:naqaaTests` | a few minutes |

### Why lint on commit but tests on push

Lint is fast enough to run on every commit and catches style violations before
they're committed. The unit test suite takes minutes, so it runs once per push
instead of stalling every commit.

UI tests (`naqaaUITests`) are intentionally excluded from the gate until they're
stable. If you want to include them, edit `pre-push`'s `-only-testing:` flags.

## Overriding things

- Lint: any SwiftLint violation fails `pre-commit`. Skip the whole check (not
  recommended) with `git commit --no-verify`.
- Tests: choose a different simulator with an env var, e.g.

```sh
TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17' git push
```

- Skip all hooks for an emergency with `git commit --no-verify` / `git push --no-verify`.

## Requirements

- [`swiftlint`](https://github.com/realm/SwiftLint) installed and on `PATH`
  (e.g. `brew install swiftlint`). `pre-commit` skips silently if it's absent.
- `xcodebuild` (comes with Xcode). A booted/available simulator is needed for
  the test gate.