# Hercules local-only architecture

Status: approved implementation direction for the Preview repository.
Working branch: `stage4-local-only`.
Production repository and live site are out of scope and must remain untouched.

## Product boundary

Hercules is a single-user, offline-first mobile app. Normal app operation must not require a network connection, hosted database, authentication server, analytics service, or cloud file store. Each installation owns its own data. Cross-device synchronization is not part of the initial release.

## Runtime design

- Keep `index.html` as the primary UI and business-logic entry point for the current product.
- Package the app with Capacitor for Android and iOS.
- Use a native SQLite database in the app-private sandbox.
- Use an encrypted SQLite implementation where the encryption key is generated and protected by Android Keystore / iOS Keychain through a vetted native adapter.
- Use native biometric APIs for convenience, with a secure PIN fallback. Biometrics unlock a locally protected key; they are not themselves database encryption.
- Keep generated PDFs, attachments, and photos in app-private storage. Do not expose raw database files or private documents through public web paths.
- No secrets, encryption keys, PINs, or biometric templates in HTML, JavaScript source, SQLite rows, or Git.

## Existing data compatibility

The current Preview `index.html` uses these localStorage keys:
- `propledger.properties`
- `propledger.receipts`
- `propledger.payments`
- `propledger.rentInvoices`
- `propledger.vendorBills`
- `propledger.vendors`
- `propledger.journalDrafts`
- `propledger.country`
- `propledger.displayCurrency`
- `propledger.language`
- `propledger.started`
- `propledger.companyLogoPreview`
- `propledger.founderPhoto`
- `propledger.profilePreview`

Migration must be additive and lossless:
1. Make a verified export of every existing key and referenced image/document before migration.
2. Import records transactionally into SQLite, preserving original IDs, dates, currencies, statuses, and source JSON.
3. Validate counts and totals before marking migration complete.
4. Keep the legacy browser data untouched until the user confirms the migrated database and a restore test succeeds.
5. Never silently replace, merge, or delete user data on migration failure.

The SQL schema stores a `legacy_json` field for source records that need a staged mapping. Complete normalized mapping is a separate implementation task; the schema alone does not perform migration.

## Accounting invariants

- Store money as integer minor units (for AED and PKR, fils/paisa) to avoid floating-point rounding.
- Every posted journal must have at least two lines, positive debit/credit values, and total debits equal total credits in the same currency.
- A journal must not post into a locked accounting period.
- Posted journals and their lines are immutable. Corrections use a separate reversing journal and a new corrected journal.
- Receipts, payments, invoices, and bills affect official reports only after an explicit validated posting workflow.
- Allocations cannot exceed the unallocated source document or invoice/bill balance.
- Reports read posted journal lines, not draft vouchers or preview-only local forms.
- Enforce transaction-level checks in a single SQLite transaction; SQL schema constraints are necessary but not sufficient.

## Backup and restore

- Provide a user-initiated encrypted backup and restore workflow.
- Include schema version, export timestamp, app version, and integrity checksum.
- Require authentication before export or restore; verify backup integrity before importing.
- Restore into a temporary database, run integrity checks, then atomically replace the active database.
- Clearly warn that uninstalling or losing the device can lose local data if the user has no external backup.
- Do not imply that device biometrics protect a backup copied outside the app; backups must be independently encrypted.

## Implementation gates

1. Inspect current working tree and make a local backup before editing the main HTML file.
2. Select and pin compatible Capacitor SQLite, encryption, secure-key-storage, and biometric adapters; verify current Android/iOS support.
3. Implement a database service and schema migrations.
4. Implement lossless import/export for all existing localStorage keys and media.
5. Implement accounting posting and allocation services with automated tests.
6. Connect existing UI screens to the database service without redesigning the current interface unnecessarily.
7. Add backup/restore and test in airplane mode.
8. Test on real Android and iOS devices before store submission.

## Security and release caveats

- A local-only design reduces server exposure but does not guarantee that nobody can access data. Device compromise, weak PINs, screenshots, unlocked backups, and insecure exports remain risks.
- Use OS-provided secure storage and native biometric prompts; do not build a fake fingerprint/Face ID screen in HTML.
- App-store distribution, crash reporting, push notifications, subscriptions, and optional cloud features can introduce online dependencies. Keep these out of the core offline accounting path.
- Do not describe reports as audited or legally certified. Accounting correctness and local data protection require testing and professional review.

## Current implementation status

- [x] Dedicated working branch created from Preview `main`.
- [x] Existing single-file HTML source inspected.
- [x] Current localStorage key inventory recorded.
- [x] Initial SQLite schema added at `database/local-schema-v1.sql`.
- [ ] Native project and plugin inventory verified from the local working copy.
- [ ] Database adapter and migrations implemented.
- [ ] Existing localStorage data migration implemented and tested.
- [ ] Posting engine and reporting integration implemented and tested.
- [ ] Encrypted backup/restore implemented and tested.
- [ ] Android and iOS device testing completed.
