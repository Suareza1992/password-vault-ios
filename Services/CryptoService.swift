import Foundation
import CryptoKit
import CommonCrypto

final class CryptoService: ObservableObject {
    static let shared = CryptoService()
    private var key: SymmetricKey?

    var isUnlocked: Bool { key != nil }

    // MARK: – Key lifecycle

    func unlock(with key: SymmetricKey) { self.key = key }

    func lock() { key = nil }

    // MARK: – Encrypt / Decrypt

    func encrypt(_ plaintext: String) throws -> String {
        guard let key else { throw VaultError.locked }
        guard !plaintext.isEmpty else { return "" }
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        return (box.combined ?? Data()).base64EncodedString()
    }

    func decrypt(_ base64: String) throws -> String {
        guard let key else { throw VaultError.locked }
        guard !base64.isEmpty else { return "" }
        guard let raw = Data(base64Encoded: base64) else { throw VaultError.badData }
        let box = try AES.GCM.SealedBox(combined: raw)
        let dec = try AES.GCM.open(box, using: key)
        return String(data: dec, encoding: .utf8) ?? ""
    }

    // MARK: – Key derivation (PBKDF2-SHA256, 600 000 iterations)

    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let pwd  = Array(password.utf8)
        let slt  = Array(salt)
        var out  = [UInt8](repeating: 0, count: 32)
        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            pwd, pwd.count,
            slt, slt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            600_000,
            &out, out.count
        )
        return SymmetricKey(data: Data(out))
    }

    static func randomSalt(bytes: Int = 32) -> Data {
        Data((0..<bytes).map { _ in UInt8.random(in: 0...255) })
    }
}

enum VaultError: LocalizedError {
    case locked, badData, wrongPassword

    var errorDescription: String? {
        switch self {
        case .locked:        return "Vault is locked."
        case .badData:       return "Could not decode encrypted data."
        case .wrongPassword: return "Incorrect master password."
        }
    }
}
