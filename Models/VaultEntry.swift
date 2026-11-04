import Foundation
import SwiftData

@Model
final class VaultEntry {
    var id:        UUID
    var siteName:  String
    var username:  String
    var password:  String   // base64-encoded AES-GCM ciphertext
    var notes:     String
    var createdAt: Date
    var updatedAt: Date

    init(siteName: String, username: String,
         password: String, notes: String = "") {
        id            = UUID()
        self.siteName  = siteName
        self.username  = username
        self.password  = password
        self.notes     = notes
        createdAt      = Date()
        updatedAt      = Date()
    }
}
