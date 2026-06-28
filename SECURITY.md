# Security Policy

## Supported versions

ShareCheck is under active MVP development. Security fixes are handled on the default branch until a stable release process is introduced.

## Reporting a vulnerability

If you find a security issue, please avoid posting sensitive details in a public issue.

Use GitHub's private vulnerability reporting feature if it is enabled for this repository. If it is not enabled, open a public issue with a minimal, non-sensitive description such as:

> Security issue found. Maintainer contact needed.

Do not include secrets, exploit payloads, personal data, screenshots containing private information, or private Photo Library contents in public issues.

## Scope

The primary security and privacy concerns for this project are:

- Accidental upload or storage of photo data
- Exposure of Photo Library identifiers beyond the local device
- Accidental commit of credentials, signing assets, provisioning profiles, or local environment files
- Unsafe GitHub Actions or release automation configuration

## Privacy expectation

ShareCheck is intended to be local-first:

- No backend server
- No account system
- No analytics
- No photo upload
- No external API key required

Changes that introduce network communication, analytics, cloud storage, external APIs, or release credentials should be reviewed explicitly before merge.
