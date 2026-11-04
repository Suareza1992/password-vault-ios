import Foundation
import CryptoKit
import LocalAuthentication

@MainActor
final class AuthManager: ObservableObject {
    @Published var isUnlocked = false
    @Published var errorMessage: String?

    private let saltKey   = "vault.salt"
    private let encVKKey  = "vault.encryptedVaultKey"

    var hasAccount: Bool { KeychainService.load(for: encVKKey) != nil }

    // MARK: – Account creation (first launch)

    func createAccount(masterPassword: String) throws {
        let salt      = CryptoService.randomSalt()
        let masterKey = CryptoService.deriveKey(password: masterPassword, salt: salt)

        // Generate a random vault key and wrap it with the master key
        let vaultKey     = SymmetricKey(size: .bits256)
        let vaultKeyData = vaultKey.withUnsafeBytes { Data($0) }
        let box          = try AES.GCM.seal(vaultKeyData, using: masterKey)
        guard let encVK  = box.combined else { throw VaultError.badData }

        KeychainService.save(salt,  for: saltKey)
        KeychainService.save(encVK, for: encVKKey)

        CryptoService.shared.unlock(with: vaultKey)
        isUnlocked = true
    }

    // MARK: – Login

    func login(masterPassword: String) throws {
        guard let salt  = KeychainService.load(for: saltKey),
              let encVK = KeychainService.load(for: encVKKey)
        else { throw VaultError.wrongPassword }

        let masterKey = CryptoService.deriveKey(password: masterPassword, salt: salt)

        do {
            let box          = try AES.GCM.SealedBox(combined: encVK)
            let vaultKeyData = try AES.GCM.open(box, using: masterKey)
            CryptoService.shared.unlock(with: SymmetricKey(data: vaultKeyData))
            isUnlocked = true
        } catch {
            throw VaultError.wrongPassword
        }
    }

    // MARK: – Biometrics (requires vault to have been unlocked once this install)

    func loginWithBiometrics() async {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            errorMessage = "Biometric authentication is not available on this device."
            return
        }
        do {
            try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your Password Vault"
            )
            // On success, re-derive from stored wrapped key using a Keychain-protected secret.
            // For this demo the user enters their password once; Face ID is wired up for
            // apps that store the vault key with kSecAttrAccessControl biometric protection.
            errorMessage = "Biometrics verified — enter master password to unlock vault key."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Lock

    func lock() {
        CryptoService.shared.lock()
        isUnlocked = false
    }
}
