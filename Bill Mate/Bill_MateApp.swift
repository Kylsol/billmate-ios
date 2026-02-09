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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = GoogleAuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

