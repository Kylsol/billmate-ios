//
//  ContentView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/21/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = GoogleAuthManager()

    private var hasValidManagerName: Bool {
        guard let name = GoogleSheetsService.shared.getManagerName() else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasHome: Bool {
        GoogleSheetsService.shared.getStoredSpreadsheetId() != nil && hasValidManagerName
    }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                SetupView()
                    .environmentObject(auth)
            } else if !hasHome {
                SetupView()
                    .environmentObject(auth)
            } else {
                DashboardView()
                    .environmentObject(auth)
            }
        }
    }
}
