## Summary

Describe what changed and why.

## Scope

- [ ] This pull request has one focused intention.
- [ ] I did not include unrelated formatting, generated files, or local machine data.
- [ ] I updated documentation where necessary.

## Data safety

- [ ] This change does not read or write real Safari or Chrome bookmark data in tests.
- [ ] This change does not weaken the App Sandbox, entitlements, backups, dry-run, idempotence, restoration, or user consent.
- [ ] If this changes a bookmark write path, prior maintainer agreement and a complete safety case are documented below.
- [ ] If this does not affect bookmark writing, the item above is not applicable.

Safety notes:

<!-- Explain effects on Core, Services, BSE, browser access, permissions, backups, and restoration. -->

## Validation

- [ ] Repository audit: `ruby Tools/audit-public-repository.rb`
- [ ] Debug build
- [ ] Release build
- [ ] Unit tests
- [ ] UI tests, or a reason they are not applicable
- [ ] `QA/Scripts/run-qa.sh`
- [ ] No new warnings

## User-visible evidence

<!-- Add sanitized screenshots only when the interface changed. Remove all private information. -->
