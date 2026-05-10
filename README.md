# PIV Signer

A native macOS app for signing and verifying files with a PIV smart card —
without OpenSC, libp11, or any other external runtime. Compatible with
YubiKey 5 (PIV applet), and any other PIV-capable token that macOS can
see through CryptoTokenKit.

## What it does

- **Sign** any file into a CMS / PKCS#7 container (`.p7m` attached or `.p7s`
  detached) using the private key on the smart card. The signing PIN
  prompt is the standard macOS dialog — the app never sees the PIN.
- **Verify** a `.p7m` file: shows each signer's certificate, signing time,
  and trust status, and lets you extract the embedded payload.
- **Inspect** any certificate (signer's or yours on the card) in the
  system Keychain Access dialog.

## Features

- 100% native: built on `Security.framework` (`CMSEncoder` / `CMSDecoder`)
  and `CryptoTokenKit`. No third-party dependencies, nothing to bundle,
  no `dylib`s to link.
- Signing profiles: create, rename, duplicate and delete profiles in the
  Settings window. Each profile defines:
  - Format — embedded `.p7m` or detached `.p7s`
  - Digest algorithm — SHA-256 / SHA-384 / SHA-512
  - Certificate chain mode — signer cert only, with intermediates, or
    full chain including the root
  - Output location — next to the source file or a custom folder
    (security-scoped bookmark)
- Batch signing: drop several files at once, get one PIN prompt for the
  whole batch, see per-file success or failure.
- Localized in 13 languages: English, German, Spanish, French, Italian,
  Japanese, Korean, Dutch, Polish, Portuguese (Brazil), Russian,
  Ukrainian, and Simplified Chinese. Adding a locale is just another
  `.lproj/Localizable.strings`.
- macOS 13 Ventura or newer.

## Build and run

Requires Xcode 15+ command-line tools (Swift 5.9).

```bash
# Run in development mode (window opens, no .app bundle)
swift run

# Build a distributable .app bundle
./Scripts/build-app.sh        # release build, written to dist/PIV Signer.app
open "dist/PIV Signer.app"

# Regenerate the app icon from Tools/MakeIcon.swift
./Scripts/build-icon.sh
```

The build script assembles a proper bundle with `Info.plist`, the
`AppIcon.icns`, and the SwiftPM module bundle (containing localized
strings) so the icon and translations work outside `swift run`.

## Usage

1. Plug in your smart card. The status row in the main window turns
   green when a certificate with a private key is detected.
2. **Sign tab**: drop one or more files into the drop zone, pick a
   profile, click *Sign*. macOS asks for the card PIN, then the signed
   files appear next to the originals (or in the custom folder set in
   the profile).
3. **Verify tab**: drop a `.p7m`, click *Verify*. The result panel
   shows whether each signature is cryptographically valid, who signed
   it, and when. *Save Original File…* extracts the embedded payload.
4. **⌘,** opens *Settings*, where you manage profiles. The first launch
   seeds a `Default` profile (SHA-256, embedded p7m, signer-only chain,
   output next to source).
5. **⌘About** shows the about window with version, license info and
   links to source and the Apache 2.0 license.

## How it works

Smart-card identities are discovered through the system Keychain by
querying `kSecAttrAccessGroupToken` — anything the OS sees as a PIV
token (YubiKey, SmartCard-HSM, IDPrime, etc.) shows up automatically as
soon as you plug it in. `TKTokenWatcher` provides the live insertion /
removal updates, so the UI reacts without a refresh button being
needed.

Signing is done by `CMSEncoder` from `Security.framework`. The signing
operation is delegated to the token through CryptoTokenKit: the OS
shows its own PIN dialog, the private key never leaves the card, and
the resulting CMS blob is written to disk.

Verification uses `CMSDecoder`, applying a basic X.509 trust policy
(`SecPolicyCreateBasicX509`) and pulling signing time from the signed
attributes when the producer included one.

The certificate inspector reuses Apple's `SFCertificatePanel` from
`SecurityInterface.framework` — the same dialog you see in Keychain
Access.

## Project layout

```
Package.swift                       SwiftPM manifest
Sources/PivSigner/
    PivSignerApp.swift              SwiftUI App entry, AppDelegate, menus
    ContentView.swift               Main window: Sign / Verify modes
    SignerCore.swift                CMSEncoder/CMSDecoder + identity discovery
    SignOptions.swift               Sign options model (codable)
    Profile.swift                   Profile model + ObservableObject store
    SettingsView.swift              ⌘, window: profile manager + editor
    AboutView.swift                 Custom About window
    CertificateInspector.swift      SFCertificatePanel wrapper
    SmartCardWatcher.swift          TKTokenWatcher live updates
    Localization.swift              Localized string helper
    Resources/
        AppIcon.icns                Multi-resolution app icon
        AppIcon.png                 PNG fallback for the About window
        en.lproj/Localizable.strings
        ru.lproj/Localizable.strings
        uk.lproj/Localizable.strings
Tools/
    MakeIcon.swift                  Core Graphics icon generator
Scripts/
    build-app.sh                    Build .app bundle into dist/
    build-icon.sh                   Regenerate AppIcon.icns + AppIcon.png
```

## Roadmap

- RFC 3161 trusted timestamps (the toggle in Settings is wired to the
  model but the operation is not implemented yet — Apple's CMSEncoder
  does not expose unsigned attributes, so a small ASN.1 layer is
  needed).
- Counter-signing existing `.p7m` files (Apple's API does not support
  this; would require a hand-written CMS encoder).

## Privacy

PIV Signer does not collect, transmit, or share any personal data.
Everything happens locally on your Mac. See [PRIVACY.md](PRIVACY.md)
for the full policy.

## License

Licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE)
and [NOTICE](NOTICE) files for details.

Copyright © 2026 FieldHub Inc. Original author: Viacheslav "Vic"
Bukhantsov.
