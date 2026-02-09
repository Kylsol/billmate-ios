//
//  AppDelegate.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/21/26.
//

import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            print("❌ Firebase clientID missing (check GoogleService-Info.plist target membership)")
        }

        return true
    }
}



