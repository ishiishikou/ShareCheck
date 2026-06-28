# Contributing to ShareCheck

Thank you for your interest in ShareCheck.

ShareCheck is a personal open-source iPhone app project. Issues and pull requests are welcome, but responses may be delayed and changes may be prioritized based on the maintainer's own use case.

## Project direction

ShareCheck is not a photo management app. It is a small utility that tracks sharing state only.

The core design principles are:

- Keep the iOS Photos app as the source of truth.
- Store only lightweight local state.
- Avoid uploading photos or videos.
- Avoid accounts, analytics, and backend services.
- Prefer standard iOS and SwiftUI behavior.
- Keep the MVP small and focused.

Before proposing a large feature, check `docs/spec.md` and existing issues or pull requests.

## Development flow

1. Create a feature branch.
2. Make a focused change.
3. Run build and tests when possible.
4. Open a pull request against `main`.

`main` should remain buildable.

## Build locally

This project uses XcodeGen.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ShareCheck.xcodeproj -scheme ShareCheck -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project ShareCheck.xcodeproj -scheme ShareCheck -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO
```

## Pull request guidelines

Please keep pull requests small and focused.

A good pull request should include:

- What changed
- Why it changed
- How it was tested
- Any privacy or security impact

Do not include:

- Real personal photos or videos
- Local logs
- `.env` files
- API keys or tokens
- Apple signing certificates
- Provisioning profiles
- App Store Connect API keys
- Generated Xcode projects or local user state

## Privacy and security review

Any change that introduces one of the following requires explicit review:

- Network communication
- Analytics
- Backend storage
- Cloud sync
- External API usage
- App Store Connect or release automation credentials
- Photo or video file persistence outside temporary sharing flow

## Feature scope

Features outside the current MVP may be declined or deferred if they increase complexity without directly reducing missed photo sharing.

Examples that are intentionally out of MVP scope:

- Full photo management
- Advanced search
- Tag management
- AI-based sharing judgment
- Automatic sharing
- Multi-level undo history
- Backend sync
