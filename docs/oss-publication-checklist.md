# OSS Publication Checklist

This checklist tracks repository-publication readiness for ShareCheck.

Current repository visibility: **public**.

## Completed

- [x] Add MIT License
- [x] Expand README for OSS visibility
- [x] Add contributing guide
- [x] Add security policy
- [x] Strengthen `.gitignore` for local files, secrets, signing assets, logs, and AI scratch files
- [x] Add issue templates for bug reports and feature requests
- [x] Add manual TestFlight distribution workflow documentation
- [x] Add CODEOWNERS entries for workflow and release-sensitive files

## Still recommended after publication

These checks require local Git or GitHub settings access and are not fully verifiable from repository files alone.

### 1. Run full-history secret scanning

Run both scanners from a fresh clone:

```bash
git clone git@github.com:ishiishikou/ShareCheck.git
cd ShareCheck

gitleaks detect --source . --log-opts="--all"
trufflehog git file://. --only-verified
```

If either scanner reports a real secret, rotate the secret first. Then remove or rewrite the exposed history as needed.

### 2. Check GitHub repository and environment secrets

Secret values cannot be retrieved, but names should be reviewed:

```bash
gh secret list -R ishiishikou/ShareCheck
gh secret list -R ishiishikou/ShareCheck --env testflight
```

Remove unused secrets. Ensure no secret value is duplicated in workflow files, README, docs, issues, pull requests, or Actions logs.

For TestFlight delivery, store signing and App Store Connect values as `testflight` environment secrets. Do not commit `.p12`, `.mobileprovision`, `.p8`, IPA, archive, or export output files.

Required TestFlight secrets are listed in `docs/testflight-github-actions.md`.

### 3. Check Actions permissions and environment protection

```bash
gh api repos/ishiishikou/ShareCheck/actions/permissions
gh api repos/ishiishikou/ShareCheck/environments/testflight
```

Recommended setting for a public repository:

- Workflow permissions: read-only by default
- Avoid automatic deploy or release workflows until credentials are reviewed
- Keep release and TestFlight workflows manual-only unless automatic delivery is explicitly reviewed
- Merge the TestFlight workflow into the default branch before expecting it to appear in the Actions UI
- Configure the `testflight` environment with required reviewers before adding signing secrets
- Enable branch protection for `main` and require CODEOWNERS review for workflow and release-sensitive configuration changes

### 4. Review public-visible metadata

Review the following periodically:

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

## Optional follow-up settings

These require repository settings access and cannot be fully completed by file edits alone.

- Add repository topics: `ios`, `swift`, `swiftui`, `photos`, `xcodegen`, `family`, `photo-library`
- Add screenshots or a short demo GIF without personal photos
- Enable private vulnerability reporting
- Enable Dependabot if package dependencies are added later
- Configure GitHub Sponsors and add `.github/FUNDING.yml` after the sponsor account is confirmed
