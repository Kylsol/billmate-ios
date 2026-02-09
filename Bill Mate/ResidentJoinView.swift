//
//  ResidentJoinView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct ResidentJoinView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var token: String = ""
    @State private var status: String = ""
    @State private var isWorking: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Join a Home")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Enter invite token (e.g. 6X9K-P2QD)", text: $token)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button(isWorking ? "Joining..." : "Join") {
                join()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((isWorking || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1.0)

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding()
    }

    private func join() {
        isWorking = true
        status = "⏳ Checking invite..."

        InviteService.shared.consumeInvite(token: token) { result in
            DispatchQueue.main.async {
                isWorking = false
                switch result {
                case .success(let spreadsheetId):
                    GoogleSheetsService.shared.storeSpreadsheetId(spreadsheetId)
                    status = "✅ Joined home"
                    dismiss()
                case .failure(let error):
                    status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
