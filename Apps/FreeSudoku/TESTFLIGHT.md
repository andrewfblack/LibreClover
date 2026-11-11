# FreeSudoku TestFlight setup

The **FreeSudoku TestFlight** GitHub Actions workflow is manual-only. It does not run on pushes or tags. Its **upload** checkbox defaults to **off**: the first run should build/export an IPA without uploading to Apple.

This follows the successful automatic/cloud-signing pattern in `andrewfblack/family-dashboard-apple`; it does not copy any credentials or reuse another app's provisioning profile.

## 1. App Store Connect and signing

- Use the same Apple Developer team as the reference repository, or explicitly choose another team.
- Register the explicit iOS bundle ID **`com.libreclover.FreeSudoku`** in that team's Developer account. No special capabilities are currently needed.
- Create its App Store Connect app record: iOS, bundle ID above, primary language English, and a unique SKU such as `libreclover-freesudoku`. The display name is provisional and subject to availability.
- Verify Apple agreements and membership are current. The API key needs access to this app and adequate rights for automatic provisioning/cloud signing and uploads; follow the working reference setup.
- Existing team/API credentials may be reused, but a profile for another bundle ID may not. Xcode must obtain a profile for FreeSudoku.

## 2. Add GitHub environment secrets

In [LibreClover → Settings → Environments → app-store](https://github.com/andrewfblack/LibreClover/settings/environments), add:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | 10-character Apple Developer team ID |
| `APP_STORE_CONNECT_KEY_ID` | 10-character App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID for that API key |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Entire raw, multiline `.p8` PEM, including BEGIN/END lines; **not base64** |

GitHub does not allow existing secret values to be read back from another repository. Use your original securely stored credentials; do not paste them into chat, commit them, or put them into repository variables. Configure required reviewers for this environment if available for your account. Do not revoke or regenerate shared credentials just for this app.

The workflow writes the private key only into the ephemeral runner's temporary/key directories, validates it without printing it, and removes it in an always-run cleanup step. Artifacts contain only the IPA, never key files. This job must stay on GitHub-hosted ephemeral runners unless cleanup/isolation is separately reviewed.

## 3. Build without uploading

1. Check that normal **FreeSudoku** iPhone/iPad CI is green for the commit being released.
2. Open **Actions → FreeSudoku TestFlight → Run workflow** on **main**.
3. Leave **upload** unchecked.
4. Inspect the result and download the `FreeSudoku-IPA-…` artifact if export succeeds. An App Store-signed IPA is not an ad-hoc build; it is not directly installable on an arbitrary iPhone.

The workflow selects Xcode 26.2, runs engine/save tests, generates the Xcode project, archives Release for generic iOS, and uses automatic signing when exporting. Simulator CI remains unsigned. Build numbers use `run_number.run_attempt`, so reruns get distinct versions. Marketing version comes from `project.yml` (currently `0.1.0`); bump it there when appropriate. If the workflow is ever recreated with reset run numbering, compare against App Store Connect before uploading.

## 4. Upload only after approval

After reviewing the signed build and release requirements, manually run the workflow again with **upload** checked. This uploads to App Store Connect/TestFlight but does **not** publish an App Store release, automatically add testers, start external beta review, or promise immediate processing. Use App Store Connect to complete beta metadata, export compliance, tester access and any required beta review.

The app currently uses no non-exempt encryption; its generated Info.plist declares `ITSAppUsesNonExemptEncryption = NO`. Reassess that declaration if dependencies or encryption features change.

## Release gates and troubleshooting

- Review GPLv3 obligations and compatibility with Apple distribution terms before distributing builds. Source licensing alone does not establish distribution compatibility.
- Approve branding/icon, review privacy manifest and App Store privacy answers, and test VoiceOver, large text, save recovery and rotation on real iPhone/iPad hardware. Simulator success is not hardware validation.
- Missing-secret errors list **names only**. Fill the `app-store` environment, not a different repository's environment.
- Provisioning failures usually require checking team/key access, bundle registration, app access and cloud-signing permissions. Do not disable validation or overwrite another app's profile to bypass them.
- If cloud signing is unavailable, stop and deliberately configure certificate/provisioning or a Match-based alternative. This workflow does not assume that a `.p8` API key alone can sign every team's app.
- Never upload credential files or entire runner temporary directories as diagnostic artifacts.

No signed FreeSudoku export or TestFlight upload is verified until this credentialed workflow actually succeeds.
