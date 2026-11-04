# Password Vault — iOS App

A cyberpunk-themed encrypted password manager for iPhone, companion to the Python desktop vault.

## Features

- **Master-password lock screen** with PBKDF2-SHA256 key derivation (600 000 iterations)
- **AES-256-GCM encryption** via CryptoKit — passwords are never stored in plaintext
- **Show / Hide button** on every entry — reveals the full password and notes inline
- Swipe to edit or delete
- Password generator with strength meter
- Search + three sort modes (Newest · A→Z · Z→A)
- Dark cyberpunk UI matching the desktop app palette

## Xcode Setup

1. **New project** → iOS App → Swift → SwiftUI → SwiftData
2. Name it `PasswordVault`, bundle ID of your choice
3. **Replace** the generated files with everything in this folder
4. Add `Utilities/Extensions.swift` (Color hex initializer)
5. In **Signing & Capabilities** → add `Keychain Sharing` capability
6. Build and run on iPhone 14+ simulator or a real device

## Project Structure

```
password-vault-ios/
├── PasswordVaultApp.swift          ← @main entry, SwiftData container
├── Models/
│   ├── VaultEntry.swift            ← SwiftData @Model
│   └── PasswordGenerator.swift     ← Pure struct, no dependencies
├── Services/
│   ├── CryptoService.swift         ← AES-GCM + PBKDF2 key derivation
│   ├── KeychainService.swift       ← Keychain read/write helpers
│   └── AuthManager.swift           ← Master password lifecycle
├── Views/
│   ├── LockView.swift              ← Login / first-launch screen
│   ├── EntryListView.swift         ← Main list + Show/Hide cards
│   └── AddEditEntryView.swift      ← Add/Edit form + generator sheet
└── Utilities/
    └── Extensions.swift            ← Color(hex:) initializer
```

## Security Notes

- The vault key (AES-256) is generated randomly at first launch and wrapped with your master key.
- Changing your master password re-wraps the vault key — entries don't need to be re-encrypted.
- Data is stored in SwiftData's sandbox directory; it is NOT synced to iCloud by default.
- To add iCloud sync: `.modelContainer(for: VaultEntry.self, cloudKitContainerIdentifier: "...")`.

## Sharing data with the macOS Python vault

The iOS app uses a different encryption format (AES-GCM vs Fernet) and storage location
(SwiftData vs SQLite at `~/.password_vault/vault.db`). To move entries between them:
- Export from Python app as a CSV → import manually in the iOS app.
- A future migration tool can convert Fernet-encrypted SQLite rows to AES-GCM SwiftData records.
