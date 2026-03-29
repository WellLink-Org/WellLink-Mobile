// AppDelegate.swift
// Handles the Auth0 callback URL (welllink://callback) after the browser redirects back.

import UIKit
import Auth0

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        // Always start with WelcomeViewController immediately
        window?.rootViewController = WelcomeViewController()
        window?.makeKeyAndVisible()

        // Then silently check for a valid saved session in the background
        AuthManager.shared.restoreSession { loggedIn in
            guard loggedIn else { return }  // stay on welcome screen
            DispatchQueue.main.async {
                // Valid session found — go straight to the main app
                let main = MainTabBarController()
                main.modalPresentationStyle = .fullScreen
                self.window?.rootViewController?.present(main, animated: false)
            }
        }
        return true
    }

    // ── Auth0 redirect callback (iOS 12 / non-Scene apps) ─────────────────
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return WebAuthentication.resume(with: url)
    }
}

// ── MARK: MainTabBarController ─────────────────────────────────────────────────
/// Simple tab bar shown after successful login.
/// Add more tabs here as your app grows.
final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let dashNav    = UINavigationController(rootViewController: ViewController())
        dashNav.tabBarItem = UITabBarItem(
            title: "Dashboard",
            image: UIImage(systemName: "heart.fill"),
            tag: 0
        )

        let profileNav = UINavigationController(rootViewController: ProfileViewController())
        profileNav.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person.circle"),
            tag: 1
        )

        viewControllers = [dashNav, profileNav]
    }
}
