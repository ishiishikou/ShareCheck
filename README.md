# ShareCheck

ShareCheck is an iPhone app for reducing missed family photo sharing.

It keeps a lightweight local ledger of photos and videos that have been shared or reviewed, without replacing the iOS Photos app.

## MVP

- Show only unprocessed media added after the management start date.
- Keep the photo-selection experience close to the iOS Photos app.
- Share selected media through the standard iOS share sheet.
- Mark selected media as shared.
- Mark remaining media as reviewed.
- Keep the latest operation available for one-step undo.

See [docs/spec.md](docs/spec.md) for the MVP specification.

## Build

This repository uses XcodeGen so the `.xcodeproj` does not need to be committed.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ShareCheck.xcodeproj -scheme ShareCheck -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs the same build on macOS.
