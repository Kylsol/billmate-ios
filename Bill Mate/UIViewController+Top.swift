//
//  UIViewController+Top.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/22/26.
//

import UIKit

extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let scenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        guard let windowScene = scenes.first else { return nil }

        let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        return root?.topMost()
    }
}

private extension UIViewController {
    func topMost() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMost()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMost()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMost()
        }
        return self
    }
}
