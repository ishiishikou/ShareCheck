# ShareCheck

ShareCheck is an open-source iPhone app project for reducing missed family photo sharing.

It does not replace the iOS Photos app. It keeps a lightweight local record of which photos and videos have already been shared or reviewed, so the user can stop wondering whether a family photo has already been shared.

## Status

This project is under active MVP development.

The current focus is a small, local-first iPhone app that manages sharing state only:

- Pending
- Shared
- Reviewed

See [docs/spec.md](docs/spec.md) for the MVP specification.

## MVP scope

- Show unprocessed media added after the management start date.
- Keep the photo-selection flow close to the iOS Photos app.
- Share selected media through the standard iOS share sheet.
- Mark selected media as shared.
- Mark remaining media as reviewed.
- Keep the latest operation available for one-step undo.
- Store state locally on device.

## Privacy model

ShareCheck is designed as a local-first app.

- No backend server
- No account system
- No analytics
- No photo upload
- No external API key required
- No photo data stored by ShareCheck
- Photo Library remains the source of truth for photos and videos

The app stores only lightweight local state, such as media identifiers and sharing status.

## Requirements

- iOS 17.0+
- Xcode 16+
- XcodeGen

## Build

This repository uses XcodeGen, so the generated `.xcodeproj` does not need to be committed.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ShareCheck.xcodeproj -scheme ShareCheck -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project ShareCheck.xcodeproj -scheme ShareCheck -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO
```

## Repository policy

- Work on feature branches.
- Keep `main` buildable.
- Use pull requests for changes.
- Do not commit real photos, local logs, credentials, signing assets, or generated Xcode artifacts.

## Contributing

Issues and pull requests are welcome, but this is a personal open-source project. Responses may be delayed, and changes may be prioritized based on the maintainer's own use case.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Security

Please do not report sensitive issues by opening a public issue with exploit details or secrets.

See [SECURITY.md](SECURITY.md) for the reporting policy.

## License

ShareCheck is available under the [MIT License](LICENSE).
