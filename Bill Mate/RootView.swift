//
//  RootView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: GoogleAuthManager

    var body: some View {
        let hasSheet = GoogleSheetsService.shared.getStoredSpreadsheetId() != nil

        if auth.isSignedIn && hasSheet {
            DashboardView()
        } else {
            SetupView()
        }
    }
}
