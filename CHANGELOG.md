# Changelog

All notable changes to BookmarkBridge are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.1-beta] - 2026-08-04

### Added

- Bidirectional Safari and Chrome synchronization.
- Chrome profile, folder, and bookmark selection before preview.
- Visual macOS Gatekeeper installation guide on the website and in the PDF manual.
- Public-repository governance, contribution, security, and community-health documentation.
- GitHub issue forms, pull request template, and non-publishing continuous integration.
- Automated repository privacy, secret-pattern, artifact, workflow, and Markdown-link checks.

### Fixed

- Stabilized scoped selections across preview, preflight, transaction, and final validation.
- Prevented unchecked items from being interpreted as deletions.
- Improved Chrome branding, bookmark-tree presentation, and DMG visuals.

### Security

- Mandatory preview, explicit confirmation, backups, validation, and rollback remain enabled.
- Unchecked items are excluded from matching and transactions without being deleted.

## [0.9.0-beta1] - 2026-07-29

### Added

- Native macOS SwiftUI application with Dashboard, synchronization preview, bookmark explorer, history, permissions, and settings.
- Safari and multi-profile Chrome bookmark readers using persistent security-scoped access.
- Additive Safari-to-Chrome synchronization with dry-run planning.
- Mandatory timestamped backup, atomic Chrome bookmark replacement, checksum generation, and persistent restoration.
- Idempotence safeguards and automatic dashboard refresh after synchronization or restoration.
- First-launch assistant, searchable offline Help Center, contextual help, FAQ, What's New, About window, and bundled user guide.
- Generated QA datasets covering small through pathological bookmark libraries.
- Reusable QA scenarios, complete one-command runner, and Markdown reports.
- Final BookmarkBridge application icon and native About-window icon presentation.
- Automated professional DMG builder.
- Automated GitHub release kit with checksum, notes, changelog, DMG, and user guide.

### Changed

- Refined the interface, design system, accessibility labels, responsive layout, and native macOS interactions.
- Prepared Debug and Release project settings for beta packaging.
- Set the marketing version to `0.9.0` and build number to `1`.

### Security

- App Sandbox remains enabled with user-selected security-scoped access.
- Browser writes require an explicit preview and confirmation.
- Chrome writes require the browser to be closed and a successful backup.
- Tests and QA scenarios operate only on generated fixtures and temporary directories.

### Known limitations

- Synchronization is one-way and additive from Safari to a selected local Chrome profile.
- Safari and `AccountBookmarks` are read-only.
- Chrome must be closed before synchronization.
- The beta is distributed without Apple signing or notarization.
- macOS 26.5 or later is required.
