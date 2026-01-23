//
//  ContentView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/21/26.
//

import SwiftUI
import GoogleSignInSwift

struct ContentView: View {
    @StateObject private var auth = GoogleAuthManager()

    var body: some View {
        VStack(spacing: 16) {
            Text("Bill Mate")
                .font(.largeTitle)

            // Show email if signed in
            if let email = auth.email {
                Text("Signed in as: \(email)")
                    .font(.subheadline)
            }

            // ALWAYS show statusText so you can see spreadsheet messages
            Text(auth.statusText)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            GoogleSignInButton {
                auth.signIn()
            }
            .frame(height: 48)
            .padding(.horizontal)

            Button("Create / Load Spreadsheet") {
                auth.statusText = "⏳ Creating/loading spreadsheet..."

                GoogleSheetsService.shared.createSpreadsheetIfNeeded { result in
                    switch result {
                    case .success(let id):
                        GoogleSheetsService.shared.storeSpreadsheetId(id)
                        auth.statusText = "✅ Spreadsheet ready: \(id)"

                        // Optional: print in console so you can confirm it fired
                        print("✅ Spreadsheet ID:", id)

                    case .failure(let error):
                        auth.statusText = "❌ Spreadsheet error: \(error.localizedDescription)"
                        print("❌ Spreadsheet error:", error)
                    }
                }
            }
            .disabled(auth.email == nil)
            .opacity(auth.email == nil ? 0.5 : 1.0)

            Button("Sign out") {
                auth.signOut()
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

