//
//  GoogleAuthManager.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/22/26.
//

import Foundation
import Combine
import UIKit
import GoogleSignIn

@MainActor
final class GoogleAuthManager: ObservableObject {

    @Published var statusText: String = "Not signed in"
    @Published var isSignedIn: Bool = false
    @Published var email: String? = nil

    // The scopes you need
    let requiredScopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive.file"
    ]

    func signIn() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            statusText = "Could not find root view controller"
            return
        }

        // ✅ Request scopes DURING sign-in (no addScopes)
        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC,
            hint: nil,
            additionalScopes: requiredScopes
        ) { [weak self] result, error in
            guard let self else { return }

            if let error = error {
                self.statusText = "Sign-in error: \(error.localizedDescription)"
                self.isSignedIn = false
                return
            }

            guard let result else {
                self.statusText = "Sign-in failed: no result"
                self.isSignedIn = false
                return
            }

            let email = result.user.profile?.email
            self.email = email
            self.isSignedIn = true

            let granted = result.user.grantedScopes ?? []   // ✅ unwrap optional
            let hasAllScopes = self.requiredScopes.allSatisfy { granted.contains($0) }

            self.statusText = hasAllScopes
                ? "Signed in ✅ + permissions granted"
                : "Signed in ⚠️ missing permissions"
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        statusText = "Signed out"
        isSignedIn = false
        email = nil
    }
}
