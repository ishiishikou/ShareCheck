# OSS Publication Checklist

This checklist tracks the remaining tasks before making the repository public as an open-source project.

## Completed in this branch

- [x] Add MIT License
- [x] Expand README for OSS visibility
- [x] Add contributing guide
- [x] Add security policy
- [x] Strengthen `.gitignore` for local files, secrets, signing assets, logs, and AI scratch files

## Must complete before changing visibility to public

These checks require local Git or GitHub settings access and are not fully verifiable from repository files alone.

### 1. Run full-history secret scanning

Run both scanners from a fresh clone:

```bash
git clone git@github.com:ishiishikou/ShareCheck.git
cd ShareCheck

gitleaks detect --source . --log-opts="--all"
trufflehog git file://. --only-verified
```

Do not make the repository public until both checks are clean or every finding has been reviewed and remediated.

### 2. Check GitHub repository secrets

Secret values cannot be retrieved, but names should be reviewed:

```bash
gh secret list -R ishiishikou/ShareCheck
```

Remove unused secrets. Ensure no secret value is duplicated in workflow files, README, docs, issues, pull requests, or Actions logs.

### 3. Check Actions permissions

```bash
gh api repos/ishiishikou/ShareCheck/actions/permissions
```

Recommended setting before public release:

- Workflow permissions: read-only by default
- Avoid automatic deploy or release workflows until credentials are reviewed
- Keep manual `workflow_dispatch` if CI minutes are a concern

### 4. Review public-visible metadata

Review the following before changing visibility:

- Open pull requests
- Branch names
- Commit messages
- Commit author identity
- Tags
- GitHub Actions history and logs
- README and docs
- Issues and PR comments

### 5. Confirm no real user data exists

Do not publish:

- Real photos or videos
- Photo Library exports
- Crash logs containing personal data
- Device logs
- Internal notes that were not intended for OSS publication

## Optional after public release

- Add repository topics: `ios`, `swift`, `swiftui`, `photos`, `xcodegen`, `family`, `photo-library`
- Add screenshots or a short demo GIF without personal photos
- Enable private vulnerability reporting
- Add branch protection for `main`
- Enable Dependabot if package dependencies are added later
