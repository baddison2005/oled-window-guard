# Distribution

Apple requires App Sandbox for Mac App Store apps and lists use of Accessibility APIs in assistive applications among functionality incompatible with the sandbox. OLED Window Guard therefore targets direct Developer ID distribution. Its current design should not be submitted to the Mac App Store as a sandboxed app.

Sources checked September 6, 2026:

- [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Reproducible packaging

The Xcode project uses the developer team already configured for Window Layouts, `SRNLN9U724`, with a distinct bundle ID, `com.astrobrett.OLEDWindowGuard`. Keep the team, bundle ID and installation path stable across releases to avoid unnecessary privacy permission changes.

Debug builds use `com.astrobrett.OLEDWindowGuard.Development` and the display name **OLED Window Guard Development**. This keeps ad-hoc/test signatures from registering under the release's Accessibility identity. Grant the development build its own permission only when live development testing is needed. Quit any development copy before running the release; the two bundle IDs have independent single-instance checks.

### If Accessibility is enabled but the app still reports denied

An existing permission can be bound to an earlier development signature. macOS may display the switch as enabled while rejecting the installed Developer ID build. A confirmed instance occurred on September 7, 2026: the TCC log reported “Failed to match existing code requirement” and showed an old `cdhash` requirement instead of the release's Developer ID requirement.

Quit all OLED Window Guard copies. Remove only OLED Window Guard from System Settings → Privacy & Security → Accessibility, then add `/Applications/OLED Window Guard.app` using the plus button and enable it. If the entry cannot be removed through the UI, the targeted supported command is `tccutil reset Accessibility com.astrobrett.OLEDWindowGuard`; then add the installed copy again. macOS may require Touch ID or the user's password. Do not reset every application's permissions or edit the TCC database.

Relaunch the installed app and confirm the permission banner disappears. This repairs the registration without modifying the signed app or disabling any macOS protections.

```sh
export DEVELOPER_ID_APPLICATION='Developer ID Application: BRETT CHRISTOPHER ADDISON (SRNLN9U724)'
export NOTARYTOOL_PROFILE='window-layouts-notary'
./Scripts/package-release.sh
```

The profile name above comes from the existing Window Layouts distribution instructions. It refers to credentials already held in Keychain; no passwords or private keys are stored in this project. If that profile does not exist, create a Keychain profile with Apple's `xcrun notarytool store-credentials` interactive flow and pass its name instead.

The script archives a universal Release app with Hardened Runtime, verifies both architectures and the signature, submits to Apple, requires an Accepted result, staples the ticket, validates it and checks Gatekeeper. It writes the app, a versioned ZIP, checksum, signing metadata and notarization response to `dist`. It refuses to overwrite the final ZIP. This does not publish to a website, create a GitHub release or submit to the App Store.

Before a public release, run the fresh-user, supported-OS and real-window checklist in [TESTING.md](TESTING.md). Notarization checks signing and malware; it is not a validation of movement behavior or App Store approval.

## GitHub updates

The About legal notice includes a qualified exclusion of warranties and liability for burn-in, image retention, display damage and related loss, while preserving rights that cannot lawfully be excluded. It is an informational notice, not a guarantee of enforceability. Source checked September 10, 2026: [ACCC consumer rights and guarantees](https://www.accc.gov.au/consumers/buying-products-and-services/consumer-rights-and-guarantees). Review the wording with legal counsel before public distribution.

The public repository is `baddison2005/oled-window-guard`. Release builds set
`OLED_UPDATE_REPOSITORY` to that repository and
`OLED_UPDATE_CHANNEL` to `stable`. The About page checks manually; no
background checks occur. The beta channel selects the highest valid numeric
three-component version from the most recent 100 GitHub releases, including
prereleases and excluding drafts. Stable builds use the explicit `stable` setting and query
GitHub's latest stable release. Tags remain numeric (for example `v0.1.20`);
GitHub's prerelease flag identifies beta releases. The packaged asset is
`OLED-Window-Guard-0.1.23-macOS.zip` and GitHub must supply its SHA-256 digest.
Older local previews require manual installation of the first connected beta.


The installer checks the download size and digest, archive paths and expansion bounds, bundle ID and version, Developer ID team and code signature, and Gatekeeper assessment. It requires guarding to be paused and the app installed at `/Applications/OLED Window Guard.app`. A staged replacement is verified before replacing the app; the previous version remains under `~/Library/Caches/OLED Window Guard/Updates/` for recovery. Installation requires write access to Applications; failures are reported without requesting administrator credentials. End-to-end download, installation and restart must be tested against actual GitHub releases before public distribution.

The packaging script also creates a Developer ID signed and notarized DMG containing the app, an Applications shortcut, and installation instructions. Both app and DMG tickets are stapled. SHA256SUMS lists both download hashes. The updater continues to use the ZIP.
