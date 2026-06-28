# TestFlight GitHub Actions Setup

This document explains how to configure the manual TestFlight distribution workflow.

Workflow file:

- `.github/workflows/testflight.yml`

The workflow is intentionally `workflow_dispatch` only. It does not run on every push or pull request because macOS minutes are limited and TestFlight uploads should be explicit.

## Prerequisites

Before running the workflow, prepare the following in Apple Developer and App Store Connect.

- A real App ID / Bundle ID for ShareCheck
  - The placeholder `com.example.ShareCheck` cannot be uploaded to TestFlight.
- An App Store Connect app record for the Bundle ID
- An Apple Distribution certificate exported as `.p12`
- An App Store provisioning profile for the same Bundle ID
- An App Store Connect API key with permission to upload builds

## Required GitHub Actions secrets

Set the following repository secrets in GitHub.

| Secret | Description |
| --- | --- |
| `APP_BUNDLE_ID` | Real Bundle ID. Example: `com.example.sharecheck` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded `.p12` Apple Distribution certificate |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded `.mobileprovision` App Store profile |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64` | Base64-encoded `.p8` private key |

## Base64 encoding examples

On macOS, encode the certificate:

```bash
base64 -i AppleDistribution.p12 | pbcopy
```

Encode the provisioning profile:

```bash
base64 -i ShareCheck_AppStore.mobileprovision | pbcopy
```

Encode the App Store Connect API private key:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Paste each copied value into the corresponding GitHub secret.

## Running the workflow

1. Open GitHub Actions.
2. Select `TestFlight Distribution`.
3. Click `Run workflow`.
4. Enter:
   - `marketing_version`, for example `1.0`
   - `build_number`, or leave empty to use the GitHub Actions run number
   - `bundle_id`, or leave empty to use `APP_BUNDLE_ID`
5. Run the workflow.

## What the workflow does

The workflow performs the following steps.

1. Checks out the repository.
2. Selects Xcode.
3. Installs XcodeGen.
4. Generates `ShareCheck.xcodeproj`.
5. Imports the Apple Distribution certificate into a temporary keychain.
6. Installs the provisioning profile.
7. Creates the App Store Connect API key file under the runner home directory.
8. Archives the app with manual signing.
9. Exports an App Store Connect IPA.
10. Uploads the IPA to TestFlight with `xcrun altool`.
11. Deletes signing material from the runner.

The signed IPA is not uploaded as a GitHub artifact. This avoids exposing a signed app package from a public repository workflow run.

## Common failure points

### Bundle ID is still `com.example.ShareCheck`

Set `APP_BUNDLE_ID` to the real App Store Bundle ID, or provide `bundle_id` when running the workflow.

### Provisioning profile does not match the Team ID

The workflow checks the profile Team ID against `APPLE_TEAM_ID` and fails early if they differ.

### Provisioning profile does not match the Bundle ID

Xcode will fail during archive or export. Regenerate the App Store provisioning profile for the exact Bundle ID used by the workflow.

### Build number already exists in App Store Connect

Use a larger `build_number`, or leave it empty and let GitHub Actions use `github.run_number`.

### Export method error

The workflow uses `app-store-connect` as the export method for current Xcode versions. If an older Xcode image is used later and rejects this method, change it to `app-store` in `ExportOptions.plist` generation.

### App Store Connect upload succeeds but TestFlight processing does not complete

The workflow only uploads the build. TestFlight processing, compliance questions, tester groups, and external review remain App Store Connect tasks.

## Security notes

- Do not commit certificates, provisioning profiles, API keys, or generated IPA files.
- Keep this workflow manual-only unless release automation is explicitly reviewed.
- Rotate App Store Connect API keys if a secret is suspected to have leaked.
- Prefer a dedicated App Store Connect API key for CI instead of using a broad personal key.
