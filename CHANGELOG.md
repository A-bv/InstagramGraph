# Changelog

All notable changes to this project are documented here. This project adheres to
[Semantic Versioning](https://semver.org).

## [3.1.0] - 2026-06-29

### Security
- Credentials (the Meta token and resolved Instagram business-account id) are now stored in the
  **Keychain** instead of `UserDefaults`, using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  so they are not synced to iCloud or included in device backups.
- Credentials persisted in `UserDefaults` by versions ≤ 3.0.2 are migrated into the Keychain
  automatically on first use. The plaintext copy is removed only after the Keychain write is
  confirmed by read-back, so a failed write never destroys the credential — migration is retried
  on the next launch.
- User-supplied values (hashtag search terms) are strictly percent-encoded when building Graph
  API URLs, closing a query-injection vector where characters such as `&`, `=`, and `+` could
  break out of the `q` parameter.

### Changed
- Graph API URLs are now assembled with `URLComponents` for consistent, correct encoding.
- Decoding failures now surface the failing coding path / type (not just a body preview), making
  Graph API schema changes easier to diagnose.

### Notes
- **macOS integrators:** Keychain access requires the app to be signed with the appropriate
  data-protection / Keychain Sharing entitlement. Validate credential persistence in a signed
  build before shipping.

## [3.0.2]
- Previous releases. See git history.
