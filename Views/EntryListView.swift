import SwiftUI
import SwiftData

struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var auth: AuthManager
    @Query(sort: \VaultEntry.updatedAt, order: .reverse) var entries: [VaultEntry]

    @State private var searchText   = ""
    @State private var showingAdd   = false
    @State private var editingEntry: VaultEntry?
    @State private var deleteTarget: VaultEntry?
    @State private var sortMode     = SortMode.dateDesc

    enum SortMode: String, CaseIterable {
        case dateDesc  = "Newest"
        case alphaAsc  = "A → Z"
        case alphaDesc = "Z → A"
    }

    var filtered: [VaultEntry] {
        let q = searchText.lowercased()
        let base: [VaultEntry] = searchText.isEmpty
            ? entries
            : entries.filter {
                $0.siteName.lowercased().contains(q) ||
                $0.username.lowercased().contains(q)
              }
        switch sortMode {
        case .dateDesc:  return base
        case .alphaAsc:  return base.sorted { $0.siteName.lowercased() < $1.siteName.lowercased() }
        case .alphaDesc: return base.sorted { $0.siteName.lowercased() > $1.siteName.lowercased() }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "0a0a14").ignoresSafeArea()

            VStack(spacing: 0) {
                // Sort picker
                Picker("Sort", selection: $sortMode) {
                    ForEach(SortMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "lock.slash")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "6868a8"))
                        Text(entries.isEmpty ? "No entries yet" : "No results")
                            .foregroundColor(Color(hex: "6868a8"))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { entry in
                                EntryCard(entry: entry) {
                                    editingEntry = entry
                                } onDelete: {
                                    deleteTarget = entry
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search entries…")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    auth.lock()
                } label: {
                    Image(systemName: "lock")
                        .foregroundColor(Color(hex: "FF0080"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Color(hex: "8000FF"))
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEditEntryView()
        }
        .sheet(item: $editingEntry) { entry in
            AddEditEntryView(entry: entry)
        }
        .confirmationDialog("Delete entry?", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let e = deleteTarget {
                    context.delete(e)
                    try? context.save()
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text(deleteTarget.map { "Permanently delete \"\($0.siteName)\"?" } ?? "")
        }
    }
}

// MARK: – Entry card with inline Show / Hide

private struct EntryCard: View {
    var entry:    VaultEntry
    var onEdit:   () -> Void
    var onDelete: () -> Void

    @State private var revealed       = false
    @State private var plainPassword  = ""
    @State private var copyFlash      = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Main row ───────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Site icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "12122e"))
                    Text(String(entry.siteName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundColor(Color(hex: "8000FF"))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.siteName)
                        .font(.headline)
                        .foregroundColor(Color(hex: "f0f0ff"))
                    Text(entry.username)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "6868a8"))

                    if !entry.notes.isEmpty && !revealed {
                        let preview = entry.notes.count > 60
                            ? String(entry.notes.prefix(60)) + "…"
                            : entry.notes
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(Color(hex: "6868a8"))
                            .padding(.top, 2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // Show / Hide
                    Button {
                        toggleReveal()
                    } label: {
                        Text(revealed ? "Hide" : "Show")
                            .font(.caption.bold())
                            .foregroundColor(revealed ? Color(hex: "00FFFF") : Color(hex: "8000FF"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "12122e"))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(revealed ? Color(hex: "00FFFF") : Color(hex: "8000FF"),
                                            lineWidth: 1)
                            )
                    }

                    // Copy password
                    Button {
                        copyPassword()
                    } label: {
                        Image(systemName: copyFlash ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(copyFlash ? Color(hex: "39FF14") : Color(hex: "6868a8"))
                    }
                }
            }
            .padding(14)

            // ── Reveal panel ───────────────────────────────────────────────
            if revealed {
                Divider()
                    .background(Color(hex: "8000FF").opacity(0.3))

                VStack(alignment: .leading, spacing: 10) {
                    // Password row
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(Color(hex: "6868a8"))
                        Text(plainPassword.isEmpty ? "•••••" : plainPassword)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(hex: "00FFFF"))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            copyPassword()
                        } label: {
                            Image(systemName: copyFlash ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copyFlash ? Color(hex: "39FF14") : Color(hex: "6868a8"))
                        }
                    }

                    // Notes
                    if !entry.notes.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(Color(hex: "6868a8"))
                            Text(entry.notes)
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "f0f0ff"))
                                .textSelection(.enabled)
                        }
                    }

                    // Edit / Delete actions
                    HStack(spacing: 12) {
                        Spacer()
                        Button("Edit") { onEdit() }
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "00FFFF"))
                        Button("Delete") { onDelete() }
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "FF0080"))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(Color(hex: "0d0d1e"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(revealed ? Color(hex: "8000FF") : Color(hex: "12122e"), lineWidth: 1)
        )
        // Swipe actions when not revealed
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color(hex: "00FFFF"))
        }
    }

    private func toggleReveal() {
        if !revealed {
            plainPassword = (try? CryptoService.shared.decrypt(entry.password)) ?? "⚠ decrypt failed"
        } else {
            plainPassword = ""
        }
        withAnimation(.spring(response: 0.3)) { revealed.toggle() }
    }

    private func copyPassword() {
        let pw = plainPassword.isEmpty
            ? ((try? CryptoService.shared.decrypt(entry.password)) ?? "")
            : plainPassword
        UIPasteboard.general.string = pw
        withAnimation { copyFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFlash = false }
        }
    }
}
