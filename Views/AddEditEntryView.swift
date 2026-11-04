import SwiftUI
import SwiftData

struct AddEditEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var entry: VaultEntry?

    @State private var siteName     = ""
    @State private var username     = ""
    @State private var password     = ""
    @State private var notes        = ""
    @State private var showPassword = false
    @State private var showGen      = false
    @State private var errorMsg     = ""

    private let gen = PasswordGenerator()

    var isEditing: Bool { entry != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a14").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Site name
                        field(label: "Site / App Name", text: $siteName,
                              placeholder: "e.g. GitHub")

                        // Username / email
                        field(label: "Username / Email", text: $username,
                              placeholder: "you@example.com")
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        // Password row
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(Color(hex: "6868a8"))
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textFieldStyle(VaultFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(Color(hex: "6868a8"))
                                }
                                .padding(.leading, 4)
                            }

                            // Password strength bar
                            if !password.isEmpty {
                                StrengthBar(password: password)
                            }

                            Button {
                                showGen = true
                            } label: {
                                Label("Generate password", systemImage: "wand.and.stars")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "8000FF"))
                            }
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes (optional)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "6868a8"))
                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .padding(10)
                                .background(Color(hex: "12122e"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "8000FF").opacity(0.4), lineWidth: 1)
                                )
                                .foregroundColor(Color(hex: "f0f0ff"))
                        }

                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .foregroundColor(Color(hex: "FF0080"))
                                .font(.caption)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "6868a8"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(siteName.isEmpty || password.isEmpty)
                        .foregroundColor(siteName.isEmpty || password.isEmpty
                            ? Color(hex: "6868a8")
                            : Color(hex: "8000FF"))
                }
            }
            .sheet(isPresented: $showGen) {
                PasswordGeneratorSheet { generated in
                    password = generated
                }
            }
            .onAppear(perform: loadEntry)
        }
    }

    // MARK: – Helpers

    @ViewBuilder
    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color(hex: "6868a8"))
            TextField(placeholder, text: text)
                .textFieldStyle(VaultFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }

    private func loadEntry() {
        guard let e = entry else { return }
        siteName = e.siteName
        username = e.username
        notes    = e.notes
        password = (try? CryptoService.shared.decrypt(e.password)) ?? ""
    }

    private func save() {
        errorMsg = ""
        guard !siteName.isEmpty, !password.isEmpty else {
            errorMsg = "Site name and password are required."
            return
        }
        guard let encrypted = try? CryptoService.shared.encrypt(password) else {
            errorMsg = "Encryption failed — is the vault unlocked?"
            return
        }
        if let e = entry {
            e.siteName   = siteName
            e.username   = username
            e.password   = encrypted
            e.notes      = notes
            e.updatedAt  = Date()
        } else {
            context.insert(VaultEntry(
                siteName: siteName, username: username,
                password: encrypted, notes: notes
            ))
        }
        try? context.save()
        dismiss()
    }
}

// MARK: – Password strength bar

private struct StrengthBar: View {
    var password: String

    private var score: (Int, String, Color) {
        var s = 0
        if password.count >= 8  { s += 1 }
        if password.count >= 12 { s += 1 }
        if password.count >= 16 { s += 1 }
        if password.contains(where: \.isUppercase) { s += 1 }
        if password.contains(where: \.isNumber)    { s += 1 }
        if password.contains(where: { "!@#$%^&*".contains($0) }) { s += 1 }
        switch s {
        case 0...2: return (s, "Weak",   Color(hex: "FF0080"))
        case 3...4: return (s, "Fair",   .orange)
        case 5:     return (s, "Good",   .yellow)
        default:    return (s, "Strong", Color(hex: "39FF14"))
        }
    }

    var body: some View {
        let (s, label, col) = score
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < s ? col : Color(hex: "12122e"))
                    .frame(height: 4)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(col)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: – Password generator sheet

struct PasswordGeneratorSheet: View {
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var length    = 20
    @State private var upper     = true
    @State private var digits    = true
    @State private var symbols   = true
    @State private var noAmb     = true
    @State private var generated = ""

    private let gen = PasswordGenerator()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a14").ignoresSafeArea()

                Form {
                    Section {
                        HStack {
                            Text(generated.isEmpty ? "Press Generate" : generated)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Color(hex: "00FFFF"))
                                .textSelection(.enabled)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = generated
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(Color(hex: "6868a8"))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "0d0d1e"))

                    Section("Options") {
                        Stepper("Length: \(length)", value: $length, in: 8...64)
                            .foregroundColor(Color(hex: "f0f0ff"))
                        Toggle("Uppercase", isOn: $upper).tint(Color(hex: "8000FF"))
                        Toggle("Digits",    isOn: $digits).tint(Color(hex: "8000FF"))
                        Toggle("Symbols",   isOn: $symbols).tint(Color(hex: "8000FF"))
                        Toggle("Avoid ambiguous (0, O, I, l)", isOn: $noAmb)
                            .tint(Color(hex: "8000FF"))
                    }
                    .listRowBackground(Color(hex: "0d0d1e"))
                    .foregroundColor(Color(hex: "f0f0ff"))

                    Section {
                        Button("Generate") { generate() }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color(hex: "8000FF"))
                            .listRowBackground(Color(hex: "0d0d1e"))

                        if !generated.isEmpty {
                            Button("Use this password") {
                                onSelect(generated)
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color(hex: "39FF14"))
                            .listRowBackground(Color(hex: "0d0d1e"))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Password Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { generate() }
    }

    private func generate() {
        let opts = PasswordGenerator.Options(
            length: length,
            uppercase: upper, lowercase: true,
            digits: digits, symbols: symbols,
            excludeAmbiguous: noAmb
        )
        generated = gen.generate(options: opts)
    }
}
