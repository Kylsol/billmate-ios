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
import FirebaseAuth

@MainActor
final class GoogleAuthManager: ObservableObject {

    @Published var statusText: String = "Not signed in"
    @Published var isSignedIn: Bool = false
    @Published var email: String? = nil

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

        statusText = "Signing in…"

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC,
            hint: nil,
            additionalScopes: requiredScopes
        ) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let error = error {
                    self.statusText = "Sign-in error: \(error.localizedDescription)"
                    self.isSignedIn = false
                    self.email = nil
                    return
                }

                guard let result = result else {
                    self.statusText = "Sign-in failed: no result"
                    self.isSignedIn = false
                    self.email = nil
                    return
                }

                self.email = result.user.profile?.email
                self.isSignedIn = true

                let granted = result.user.grantedScopes ?? []
                let hasAllScopes = self.requiredScopes.allSatisfy { granted.contains($0) }

                self.statusText = hasAllScopes
                    ? "Signed in ✅ (Google) — linking Firebase…"
                    : "Signed in ⚠️ missing Google permissions"

                // ✅ Bridge Google session -> Firebase Auth
                await self.signIntoFirebase(using: result.user)
            }
        }
    }

    private func signIntoFirebase(using googleUser: GIDGoogleUser) async {
        guard let idToken = googleUser.idToken?.tokenString else {
            statusText = "Firebase link failed: missing Google ID token"
            return
        }

        let accessToken = googleUser.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            let uid = authResult.user.uid
            statusText = "Signed in ✅ (Firebase uid: \(uid.prefix(6))…)"
            print("✅ Firebase signed in. UID:", uid)
        } catch {
            statusText = "Firebase sign-in failed: \(error.localizedDescription)"
            print("❌ Firebase sign-in failed:", error)
        }
    }

    func signOut() {
        // Google sign-out
        GIDSignIn.sharedInstance.signOut()

        // Firebase sign-out
        do { try Auth.auth().signOut() } catch { }

        statusText = "Signed out"
        isSignedIn = false
        email = nil
    }
}
