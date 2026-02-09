//
//  ManageHomeView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/9/26.
//

import SwiftUI

struct ManageHomeView: View {
    @EnvironmentObject var auth: GoogleAuthManager

    @State private var managerName: String = ""
    @State private var roommates: [Roommate] = []
    @State private var status: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Manage Home")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            .padding(.top)

            if isLoading { ProgressView() }

            List {
                Section("Roommates") {
                    if roommates.isEmpty {
                        Text("No roommates yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(roommates) { r in
                            HStack {
                                Text(r.name)
                                Spacer()
                                if r.isManager {
                                    Text("Manager")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Section("Invites") {
                    Button {
                        createInvite()
                    } label: {
                        Label("Invite roommate (copy token)", systemImage: "person.badge.plus")
                    }
                    .disabled(isLoading)

                    // Residents should not manage removals in your model.
                    // You can wire up remove later if you want manager-only controls.
                    Button(role: .destructive) {
                        status = "Remove roommate (manager-only) — coming next."
                    } label: {
                        Label("Remove roommate", systemImage: "person.badge.minus")
                    }
                    .disabled(true)
                }
            }
            .listStyle(.insetGrouped)

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        isLoading = true
        status = "Loading…"

        // 1) Resolve manager name (local if present, else from Home sheet)
        let localManager = (GoogleSheetsService.shared.getManagerName() ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !localManager.isEmpty {
            self.managerName = localManager
            loadRoommates(usingManager: localManager)
            return
        }

        GoogleSheetsService.shared.fetchManagerNameFromHome { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let manager):
                    self.managerName = manager
                    self.loadRoommates(usingManager: manager)
                case .failure(let error):
                    self.isLoading = false
                    self.status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadRoommates(usingManager manager: String) {
        GoogleSheetsService.shared.fetchRoommates { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let names):
                    self.roommates = names.map {
                        Roommate(name: $0, isManager: $0.caseInsensitiveCompare(manager) == .orderedSame)
                    }
                    self.status = ""
                case .failure(let error):
                    self.roommates = []
                    self.status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }

    private func createInvite() {
        guard let spreadsheetId = GoogleSheetsService.shared.getStoredSpreadsheetId() else {
            status = "No home found."
            return
        }

        let createdBy = auth.email ?? "unknown"
        status = "⏳ Creating invite..."

        InviteService.shared.createInvite(
            spreadsheetId: spreadsheetId,
            createdBy: createdBy,
            ttlHours: 72,
            maxUses: 5
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    UIPasteboard.general.string = token
                    status = "✅ Invite token copied: \(token)"
                case .failure(let error):
                    status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
