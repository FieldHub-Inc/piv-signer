# Privacy Policy

**Effective date:** 2026-05-09

PIV Signer ("the app") is developed and published by **FieldHub Inc.**
This document describes what the app does — and does not do — with
your data.

## TL;DR

PIV Signer does not collect, transmit, or share any personal data.
Everything happens locally on your Mac. The app has no servers, no
analytics, no telemetry, and no advertising.

## What information the app accesses

The app accesses, **only on your explicit action**, the following data
on your local device:

- **Files you choose** — when you drop a file onto the app or pick one
  through the system file dialog, the app reads its contents to
  produce a digital signature, and writes the resulting `.p7m` /
  `.p7s` file either next to the source file or to a folder you
  selected. No file content is ever sent off the device.
- **Your PIV smart-card certificate and private-key reference** — when
  a PIV-capable smart card (such as a YubiKey) is inserted, macOS
  exposes the certificate and a reference to the private key through
  CryptoTokenKit. The app reads the certificate to display its
  subject, issuer, and validity. The private key never leaves the
  card. Any signing operation triggers the standard macOS PIN dialog;
  the app never sees, stores, or logs your PIN.
- **App preferences** — your signing profiles (name, format, digest
  algorithm, certificate-chain mode, output location) are stored in
  the macOS user defaults database for this app, locally on your
  device. No profile data leaves your Mac.

## What the app does not do

- The app **does not make any network connections.** It has no
  telemetry, no crash reporting, no auto-update mechanism, no remote
  configuration.
- The app **does not collect, transmit, share, or sell** personal
  information of any kind.
- The app **does not access** the camera, microphone, location, photo
  library, contacts, calendar, or any other user-protected resource.
- The app **does not use third-party SDKs** that could collect data on
  its behalf.
- The app **does not read or write files** outside of the explicit
  inputs and outputs you select.

## Where signed files end up

By default, signed files are saved next to the source file you
selected. If you configure a profile to use a custom output folder,
the app stores a security-scoped bookmark to that folder in its
preferences database, used solely to write output files there on
future signings.

## Data retention

Because the app does not collect data, there is nothing to retain. The
local data described above (preferences, security-scoped bookmarks)
remains on your device until you delete the app or remove its
preferences. You can reset all preferences with:

```
defaults delete com.fieldhub.PivSigner
```

## Your rights

Because no data leaves your device, there is no remote profile or
account associated with your use of the app. All data is fully under
your control on your Mac. To delete everything PIV Signer has stored,
delete the app and run the `defaults delete` command above.

## Third parties

PIV Signer relies exclusively on Apple's frameworks shipped with
macOS — `Security`, `SecurityInterface`, `CryptoTokenKit`, and
`SwiftUI` — for all cryptographic and UI functionality. The app does
not bundle, link, or contact any third-party service.

## Changes to this policy

If this policy is updated, the new version will be committed to the
project repository at
https://github.com/FieldHub-Inc/piv-signer/blob/main/PRIVACY.md and
the *Effective date* above will be updated. Earlier versions remain
available in the repository's Git history.

## Contact

Questions or concerns about privacy can be filed as an issue at
https://github.com/FieldHub-Inc/piv-signer/issues, or sent to the
contact listed on FieldHub Inc.'s website.
