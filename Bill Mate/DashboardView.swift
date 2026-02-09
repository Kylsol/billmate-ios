//
//  DashboardView.swift
//  Bill Mate
//
//  Account Manager Dashboard (API-only + Firestore invite token)
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: GoogleAuthManager

    @State private var rows: [RoommateBalance] = []
    @State private var status: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Header
                HStack {
                    Text("🏠 House Balance Summary")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    // Invite token (Firestore)
                    Button {
                        createInvite()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .disabled(isLoading)

                    // Refresh
                    Button {
                        loadSummary()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)

                // Table-like header
                HStack {
                    Text("Name").fontWeight(.semibold)
                    Spacer()
                    Text("Amount Owed ($)").fontWeight(.semibold)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))

                // Table
                List {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.name)
                            Spacer()

                            Text(row.amountOwed.formatted(.currency(code: "USD")))
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    row.amountOwed < 0
                                    ? .green
                                    : (row.amountOwed > 0 ? .red : .primary)
                                )
                        }
                    }
                }
                .listStyle(.plain)

                // Loading
                if isLoading {
                    ProgressView()
                }

                // Status
                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action tiles
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NavigationLink {
                            BillsView()
                        } label: {
                            tileButtonLabel("Bills", systemImage: "doc.text")
                        }

                        NavigationLink {
                            PaymentsView()
                        } label: {
                            tileButtonLabel("Payments", systemImage: "creditcard")
                        }
                    }

                    HStack(spacing: 12) {
                        NavigationLink {
                            ManageHomeView()
                                .environmentObject(auth)
                        } label: {
                            tileButtonLabel("Manage Home", systemImage: "house")
                        }

                        tileButton("Help", systemImage: "questionmark.circle") {
                            status = "Manage Home → invite roommates."
                        }
                    }

                }
                .padding(.horizontal)

                // Bottom controls
                HStack(spacing: 16) {
                    Button("Sign out") {
                        auth.signOut()
//                        GoogleSheetsService.shared.clearStoredSpreadsheetId()
                        // If you added clearManagerName() in GoogleSheetsService, uncomment:
                        // GoogleSheetsService.shared.clearManagerName()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 12)
            }
            .onAppear {
                loadSummary()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    // MARK: - Data loading

    private func loadSummary() {
        // Require manager name
        guard let manager = GoogleSheetsService.shared.getManagerName(),
              !manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            isLoading = false
            status = "No manager name set. Create a home first."
            rows = []
            return
        }

        // Require spreadsheet id
        guard GoogleSheetsService.shared.getStoredSpreadsheetId() != nil else {
            isLoading = false
            status = "No home found. Create a home first."
            rows = []
            return
        }

        isLoading = true
        status = "Loading…"

        GoogleSheetsService.shared.fetchComputedSummary(managerName: manager) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let balances):
                    self.rows = balances
                    self.status = balances.isEmpty
                        ? "No summary rows found."
                        : "✅ Loaded \(balances.count) rows"
                case .failure(let error):
                    self.rows = []
                    self.status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Invite token

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

    // MARK: - Tile helpers

    private func tileButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            tileButtonLabel(title, systemImage: systemImage)
        }
    }

    private func tileButtonLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(title)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
