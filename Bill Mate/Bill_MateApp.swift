//
//  Bill_MateApp.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/21/26.
//

import SwiftUI
import GoogleSignIn

@main
struct Bill_MateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // This is required so Google Sign-In can resume the auth flow
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
