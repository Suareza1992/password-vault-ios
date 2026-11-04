import SwiftUI

struct LockView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var password      = ""
    @State private var confirmPass   = ""
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "0a0a14").ignoresSafeArea()

            VStack(spacing: 36) {
                // Icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "8000FF"), Color(hex: "FF00FF")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("Password Vault")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color(hex: "f0f0ff"))

                VStack(spacing: 14) {
                    SecureField("Master password", text: $password)
                        .textFieldStyle(VaultFieldStyle())
                        .onSubmit { attempt() }
                        .offset(x: shakeOffset)

                    if !auth.hasAccount {
                        SecureField("Confirm password", text: $confirmPass)
                            .textFieldStyle(VaultFieldStyle())
                            .onSubmit { attempt() }

                        Text("First launch — this password will unlock your vault forever.")
                            .font(.caption)
                            .foregroundColor(Color(hex: "6868a8"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Color(hex: "FF0080"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: attempt) {
                        Text(auth.hasAccount ? "Unlock" : "Create Vault")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "8000FF"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(password.isEmpty)

                    if auth.hasAccount {
                        Button {
                            Task { await auth.loginWithBiometrics() }
                        } label: {
                            Label("Use Face ID / Touch ID", systemImage: "faceid")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "00FFFF"))
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            if auth.hasAccount {
                Task { await auth.loginWithBiometrics() }
            }
        }
    }

    private func attempt() {
        auth.errorMessage = nil
        do {
            if auth.hasAccount {
                try auth.login(masterPassword: password)
            } else {
                guard password == confirmPass else {
                    auth.errorMessage = "Passwords do not match."
                    shake(); return
                }
                guard password.count >= 8 else {
                    auth.errorMessage = "Password must be at least 8 characters."
                    shake(); return
                }
                try auth.createAccount(masterPassword: password)
            }
        } catch {
            auth.errorMessage = error.localizedDescription
            shake()
            password    = ""
            confirmPass = ""
        }
    }

    private func shake() {
        withAnimation(.spring(response: 0.1).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeOffset = 0 }
    }
}

// MARK: – Custom text field style

struct VaultFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: "12122e"))
            .foregroundColor(Color(hex: "f0f0ff"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "8000FF").opacity(0.5), lineWidth: 1)
            )
    }
}
