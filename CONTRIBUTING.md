# Contributing to BookmarkBridge

Thank you for helping make bookmark synchronization safer and easier to understand.

## Before you start

Please read:

- [AGENTS.md](AGENTS.md), the project's engineering source of truth.
- [Code of Conduct](CODE_OF_CONDUCT.md).
- [Security Policy](SECURITY.md) before reporting a vulnerability.

For substantial changes, open an issue before writing code. This is especially important for changes involving browser access, permissions, synchronization, backups, or restoration.

## Prerequisites

- macOS 26.5 or later.
- Xcode 26.5 or later.
- Swift 6 with strict concurrency enabled.
- Git.

No third-party dependency is required.

## Open the project

```sh
open BookmarkBridge.xcodeproj
```

Select the shared `BookmarkBridge` scheme and the local Mac destination.

## Build

Debug:

```sh
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Debug \
  -destination 'platform=macOS'
```

Release:

```sh
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Release \
  -destination 'platform=macOS'
```

## Tests

Unit and integration tests:

```sh
xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeTests
```

UI tests require an active graphical macOS session:

```sh
xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeUITests
```

CI compiles the UI-test bundle but does not execute it because the XCUI runner must be signed to bootstrap. The public workflow intentionally performs no signing and uses no Apple credentials. Run the suite locally before opening a pull request.

Complete QA platform:

```sh
QA/Scripts/run-qa.sh
```

Run a single generated QA scenario:

```sh
QA/Scripts/run-qa.sh --qa-only --scenario first-sync
```

All tests must use fixtures or temporary directories. Never point a test at real Safari or Chrome bookmark data.

## Safety and protected areas

The V1 synchronization engine is frozen. Do not change these areas without prior maintainer agreement:

- `BookmarkBridge/Core/`
- `BookmarkBridge/Services/`, if present
- BSE, matching, diffing, planning, rollback, repositories, permissions, or synchronization code

Any approved write-path change must demonstrate:

1. Read-only discovery and a dry-run preview.
2. A restorable timestamped backup before mutation.
3. Idempotence and reversibility.
4. Safe browser state.
5. Explicit, informed user consent.
6. Unit and integration coverage for success and failure paths.

Never disable the App Sandbox or weaken entitlements to make a test pass.

## Coding conventions

- Follow the Swift API Design Guidelines and the surrounding code style.
- Use immutable, `Sendable` domain values.
- Keep `Core` independent from SwiftUI and presentation code.
- Use constructor injection and small protocols; do not introduce hidden singletons.
- Use `async`/`await` for new asynchronous work.
- Do not use `try!`, production `fatalError`, or force unwraps without a proven invariant.
- Keep the build warning-free.
- Add a regression test for every bug fix.
- Avoid unrelated formatting or refactoring in the same change.

## Commits

Use Conventional Commits:

```text
type(scope): short imperative subject
```

Accepted types include `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, and `ci`. Keep the subject at or below 72 characters and make each commit atomic.

## Pull requests

1. Create a focused branch such as `feature/...`, `fix/...`, or `chore/...`.
2. Keep the change limited to one intention.
3. Update tests and documentation.
4. Run Debug and Release builds, applicable tests, and the QA platform.
5. Complete the pull request checklist and explain safety implications.
6. Address review feedback without hiding or suppressing warnings.

Pull requests that can write bookmark data must explicitly document how every safety rule above is satisfied.

## Secrets and personal data

Never commit:

- API keys, tokens, passwords, private keys, or certificates.
- Provisioning profiles or signing identities.
- `.env` files containing real values.
- Personal email addresses, local usernames, or absolute home-directory paths.
- Real Safari or Chrome bookmark libraries.
- Logs, screenshots, or QA reports containing private browsing data.
- Xcode user data, DerivedData, archives, or other generated artifacts.

Use placeholders, relative paths, generated fixtures, and environment variables. Before opening a pull request, run:

```sh
ruby Tools/audit-public-repository.rb
```

If a secret was committed, do not merely delete it in a later commit. Revoke it immediately and privately contact the maintainers through the process in [SECURITY.md](SECURITY.md).
