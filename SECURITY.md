# Security Policy

BookmarkBridge handles browser bookmark libraries, so data integrity and local privacy are security concerns.

## Supported versions

| Version | Supported |
| --- | --- |
| 0.9.1 Beta | Yes |
| 0.9.0-beta1 | No |
| Earlier development builds | No |

Security updates target the latest published beta or stable release.

## Report a vulnerability privately

Do not open a public issue for a suspected vulnerability.

When GitHub private vulnerability reporting is enabled for this repository:

1. Open the repository's **Security** tab.
2. Select **Advisories**.
3. Choose **Report a vulnerability**.
4. Include the affected version, impact, reproduction steps, and any safe proof of concept.

Remove real bookmarks, browser profiles, usernames, file paths, tokens, and other personal information before submitting evidence. If private vulnerability reporting is not available, wait for a private contact method to be published in the repository settings rather than disclosing the issue publicly.

## What to expect

Maintainers will:

- Acknowledge a complete private report as capacity allows.
- Validate the issue without using real user bookmark data.
- Coordinate remediation and disclosure with the reporter.
- Credit the reporter when requested and appropriate.

Please allow time for investigation before any public disclosure. This project is maintained on a best-effort basis and cannot guarantee a fixed response deadline.

## Scope

Reports are especially useful when they concern:

- Data loss, corruption, or an unsafe synchronization path.
- Sandbox or security-scoped access bypasses.
- Unauthorized file access.
- Backup or restoration failures that could expose or lose data.
- Secrets or personal information committed to the repository or release assets.

General bugs and feature requests belong in the corresponding public issue form when they do not contain sensitive information.
