import SwiftUI
import SwiftData

@main
struct PasswordVaultApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            if auth.isUnlocked {
                NavigationStack {
                    EntryListView()
                }
                .environmentObject(auth)
            } else {
                LockView()
                    .environmentObject(auth)
            }
        }
        .modelContainer(for: VaultEntry.self)
    }
}
