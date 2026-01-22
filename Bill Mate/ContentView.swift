//
//  ContentView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/21/26.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct ContentView: View {
    @State private var statusText = "Not signed in"

    var body: some View {
        VStack(spacing: 16) {
            Text("Bill Mate")
                .font(.largeTitle)

            Text(statusText)
                .font(.subheadline)

            GoogleSignInButton {
                signIn()
            }
            .frame(height: 48)
            .padding(.horizontal)

            Button("Sign out") {
                GIDSignIn.sharedInstance.signOut()
                statusText = "Signed out"
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func signIn() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            statusText = "Could not find root view controller"
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                statusText = "Sign-in error: \(error.localizedDescription)"
                return
            }

            let email = result?.user.profile?.email ?? "Signed in (no email)"
            statusText = "Signed in as: \(email)"
        }
    }
}
