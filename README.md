# BookmarkBridge

BookmarkBridge is a native macOS application for previewing and safely synchronizing bookmarks from Safari to local Google Chrome profiles.

> [!IMPORTANT]
> BookmarkBridge 0.9.0-beta1 is beta software. Review every synchronization preview and keep browser backups. The current beta build is distributed without Apple signing or notarization.

## Goals

BookmarkBridge is designed around one promise: bookmark data must remain understandable, recoverable, and under the user's control.

- Read Safari and Chrome bookmark libraries locally.
- Explain differences before changing anything.
- Require explicit confirmation before synchronization.
- Back up Chrome data before every write.
- Keep synchronization idempotent and reversible.
- Operate offline without accounts, analytics, or cloud storage.

## Main features

- Native SwiftUI interface for macOS.
- Safari and multi-profile Chrome library discovery.
- Hierarchical bookmark explorer with search and breadcrumbs.
- Read-only scan and comparison workflow.
- Dry-run synchronization plan before application.
- Additive Safari-to-Chrome synchronization.
- Timestamped Chrome backups with restoration support.
- Synchronization history and audit information.
- First-launch assistant, contextual help, FAQ, What's New, and offline user guide.
- Automated quality-assurance, DMG, and GitHub release-kit builders.

## Requirements

- macOS 26.5 or later.
- Xcode 26.5 or later to build from source.
- Swift 6.
- Safari and/or Google Chrome for normal use.

The project uses the macOS App Sandbox and user-selected security-scoped access. Do not disable the sandbox to work around permission issues.

## Install from the DMG

When a release asset is available:

1. Open the BookmarkBridge DMG.
2. Drag `BookmarkBridge.app` onto the `Applications` alias.
3. Eject the disk image.
4. Open BookmarkBridge from Applications.

The beta is not signed or notarized. macOS may therefore require an explicit confirmation before the first launch. Do not disable Gatekeeper globally.

## First launch

The onboarding assistant explains how BookmarkBridge works and asks you to select the Safari and Chrome bookmark locations through the standard macOS file picker. BookmarkBridge stores only security-scoped references needed to reopen those locations.

Before the first synchronization:

1. Grant access only to the bookmark libraries you want to use.
2. Run a scan.
3. Review the comparison and dry-run plan.
4. Close Chrome when prompted.
5. Confirm synchronization only when the preview is correct.

## Build from source

Clone the repository, then open `BookmarkBridge.xcodeproj` in Xcode, or build from Terminal:

```sh
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Debug \
  -destination 'platform=macOS'
```

For a Release build:

```sh
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Release \
  -destination 'platform=macOS'
```

No third-party dependency is required.

## Tests and QA

Run the unit-test target:

```sh
xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeTests
```

Run the UI-test target from an active macOS graphical session:

```sh
xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeUITests
```

The public CI compiles the UI-test bundle but does not launch it. XCUI requires its runner application to be signed before it can bootstrap, while this repository's CI is intentionally unsigned and uses no Apple credentials. The complete UI suite remains a required local validation in an active graphical session.

Run the complete reusable QA platform:

```sh
QA/Scripts/run-qa.sh
```

Tests use generated fixtures and temporary directories. They never read or write real Safari or Chrome bookmarks. See [QA documentation](QA/Documentation/README.md) for individual scenarios and advanced options.

## Architecture

BookmarkBridge follows MVVM with dependencies directed toward small protocols:

```text
SwiftUI Views → ViewModels → Core protocols ← Services and repositories
```

- `BookmarkBridge/App/` — application entry point and dependency composition.
- `BookmarkBridge/Core/` — immutable domain models, parsers, synchronization engine, security, and browser access.
- `BookmarkBridge/Features/` — vertical SwiftUI features and presentation state.
- `BookmarkBridge/Shared/` — reusable UI components and resources.
- `BookmarkBridgeTests/` — unit and integration tests using isolated fixtures.
- `BookmarkBridgeUITests/` — critical user journeys.
- `QA/` — generated datasets, scenarios, runner, and reports.
- `Documentation/` and `Docs/` — project status, architecture decisions, and release documentation.
- `Distribution/` — reusable DMG and GitHub release-kit automation.

For a detailed technical handover, read [Project Status](Documentation/PROJECT_STATUS.md) and the [architecture decisions](Docs/adr/).

## Known limitations

- Synchronization is currently one-way and additive: Safari to a selected local Chrome profile.
- Safari and `AccountBookmarks` remain read-only.
- Chrome must be closed before BookmarkBridge writes its bookmark file.
- The beta is not signed or notarized.
- macOS 26.5 or later is required.

Only confirmed limitations are tracked in [Known Issues](Documentation/KNOWN_ISSUES.md).

## Documentation

- [Offline User Guide](BookmarkBridge/Documentation/Resources/BookmarkBridge-User-Guide.pdf)
- [Release Notes for 0.9.0-beta1](Documentation/RELEASE_NOTES_0.9.0-beta1.md)
- [DMG Builder](Distribution/DMG/README.md)
- [GitHub Release Kit](Distribution/GitHub/README.md)
- [QA Platform](QA/Documentation/README.md)

The same user documentation is available inside the application from the Help menu.

## Roadmap

The immediate roadmap is deliberately conservative:

1. Validate 0.9.x beta behavior with real-world libraries and fix confirmed defects.
2. Add Apple Developer signing and notarization when distribution credentials are available.
3. Prepare 1.0 after beta stability and compatibility criteria are met.

Possible post-1.0 work is documented separately and does not change the safety requirements or the read-only-before-write principle.

## Contributing

Contributions are welcome when they preserve BookmarkBridge's data-safety guarantees. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow the [Code of Conduct](CODE_OF_CONDUCT.md), and include tests for behavior changes.

The V1 synchronization engine is frozen. Changes to `Core`, services, parsers, repositories, permissions, or BSE require prior maintainer agreement and a documented safety case.

## Security

Do not report vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md) to use GitHub's private vulnerability-reporting channel when it is available.

## License

BookmarkBridge is available under the [MIT License](LICENSE).

Copyright (c) 2026 Jérôme Hudeček.
