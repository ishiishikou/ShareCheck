# TestFlight GitHub Actions Setup

This document explains how to configure automatic TestFlight distribution after successful `main` CI, with an explicit opt-in gate and a manual fallback.

Workflow file:

- `.github/workflows/testflight.yml`

CI runs on pull requests and pushes to `main`. TestFlight distribution runs automatically only after a successful `main` push CI run, and only when the repository variable `TESTFLIGHT_AUTO_DEPLOY` equals `true`. The manual `workflow_dispatch` fallback is restricted to `main`. Public repositories can use standard GitHub-hosted macOS runners without compute charges; release signing still needs protection.

## Security model

The workflow uses the `testflight` GitHub Actions environment.

Configure the following environment protection before adding signing secrets.

- Environment name: `testflight`
- Deployment branches: restrict to `main`
- Required reviewers: **disabled for fully automatic delivery** (enabling them intentionally pauses every release for approval)
- Protect `main` and `.github/workflows/` changes with PR reviews and checks before enabling automatic signing

Secrets for signing and App Store Connect upload should be stored as `testflight` environment secrets, not broad repository secrets.

The workflow also keeps secrets out of the job-level environment. Certificate, provisioning profile, and private key values are passed only to the steps that need them.

## Prerequisites

Before running the workflow, prepare the following in Apple Developer and App Store Connect.

- A real App ID / Bundle ID for ShareCheck
  - The placeholder `com.example.ShareCheck` cannot be uploaded to TestFlight.
- An App Store Connect app record for the Bundle ID
  - The app record must exist before the first upload.
- An Apple Distribution certificate exported as `.p12`
- An App Store provisioning profile for the same Bundle ID
- An App Store Connect API key with permission to upload builds

## Required GitHub Actions environment secrets

Set the following secrets on the `testflight` environment in GitHub.

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

Paste each copied value into the corresponding GitHub environment secret.

## Enable automatic delivery

1. Create the `testflight` environment with branch restrictions and configure all eight signing secrets.
2. Make one manual release on `main` and confirm the IPA upload succeeds before enabling unattended releases.
3. In **Settings → Secrets and variables → Actions → Variables**, set the repository variable `TESTFLIGHT_AUTO_DEPLOY` to `true`.
4. Optionally set `TESTFLIGHT_MARKETING_VERSION` to the intended version (defaults to `1.0`). Update it before increasing the App Store Connect marketing version.
5. Merge a PR to `main`. The `iOS Build` workflow runs on the `main` push. If it succeeds, `TestFlight Distribution` checks out **that exact tested commit** and uploads automatically.

To pause automatic releases without changing source, change `TESTFLIGHT_AUTO_DEPLOY` to `false` or delete that variable. Missing/false values skip the release job. CI continues to run.

## Manual fallback

1. Open GitHub Actions and select `TestFlight Distribution`.
2. Click `Run workflow` and select **`main`**.
3. Enter the `marketing_version`, optional `build_number` (defaults to this workflow's run number), and optional `bundle_id` (defaults to `APP_BUNDLE_ID`).
4. Run the workflow. Manual runs remain available when `TESTFLIGHT_AUTO_DEPLOY` is disabled; an environment with required reviewers still requires approval.

## What the workflow does

The workflow performs the following steps.

1. Checks out the repository.
2. Selects Xcode.
3. Validates required configuration and exposes only non-sensitive derived values to later steps.
4. Installs XcodeGen.
5. Generates `ShareCheck.xcodeproj`.
6. Imports the Apple Distribution certificate into a temporary keychain.
7. Installs the provisioning profile.
8. Creates the App Store Connect API key file under the runner home directory.
9. Archives the app with manual signing.
10. Exports an App Store Connect IPA.
11. Uploads the IPA to TestFlight with `xcrun altool`.
12. Deletes signing material from the runner.

The signed IPA is not uploaded as a GitHub artifact. This avoids exposing a signed app package from a public repository workflow run.

The workflow only needs read-only repository contents permission. App Store Connect authentication is handled by the environment secrets. Automatic delivery uses `workflow_run` only for successful push-based `iOS Build` runs on `main`, never for a PR result; it does not download CI artifacts or execute PR-provided scripts.

## Common failure points

### Bundle ID is still `com.example.ShareCheck`

Set `APP_BUNDLE_ID` to the real App Store Bundle ID, or provide `bundle_id` when running the workflow.

### The workflow waits for approval

The workflow references the `testflight` environment. If required reviewers are configured, every release waits for deployment approval. Disable this rule only after the `main` branch and release-workflow files are appropriately protected and unattended delivery is desired.

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

## Pull request limitation

The `workflow_run` trigger only becomes active when this workflow file exists on the default branch. PR builds never receive TestFlight signing secrets. Merging the automation PR is not sufficient to enable automatic delivery: `TESTFLIGHT_AUTO_DEPLOY=true` must also be configured.

## Merge order

The automation PR may be merged before Apple signing assets are prepared because `TESTFLIGHT_AUTO_DEPLOY` defaults to disabled. Configure secrets and verify a manual release before enabling the repository variable. A successful automatic workflow upload does not prove TestFlight processing or tester distribution completed.

## Security notes

- Do not commit certificates, provisioning profiles, API keys, or generated IPA files.
- Keep `TESTFLIGHT_AUTO_DEPLOY` disabled until initial manual upload and release permissions have been verified.
- Rotate App Store Connect API keys if a secret is suspected to have leaked.
- Prefer a dedicated App Store Connect API key for CI instead of using a broad personal key.
- Protect `.github/workflows/` and release configuration changes with review rules before relying on CI signing.
