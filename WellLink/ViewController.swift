// ViewController.swift
// Main dashboard — only shown when the user is authenticated.
// Shows the user's name, role, and the sync button.

import UIKit

final class ViewController: UIViewController {

    // MARK: - UI
    private let logoView        = LogoView()
    private let greetingLabel   = UILabel()
    private let roleLabel       = UILabel()
    private let syncButton      = PrimaryButton(title: "Sync Health Data Now")
    private let logoutButton    = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        buildLayout()
        populateUser()

        HealthSyncManager.shared.requestNotificationPermission()
        HealthSyncManager.shared.scheduleWeeklySync()
    }

    // MARK: - Layout
    private func buildLayout() {
        [logoView, greetingLabel, roleLabel, syncButton, logoutButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        logoutButton.setTitle("Log out", for: .normal)
        logoutButton.setTitleColor(.systemRed, for: .normal)

        greetingLabel.font          = .systemFont(ofSize: 22, weight: .semibold)
        greetingLabel.textAlignment = .center

        roleLabel.font          = .systemFont(ofSize: 15)
        roleLabel.textColor     = .secondaryLabel
        roleLabel.textAlignment = .center

        let p: CGFloat = 24
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),

            greetingLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 40),
            greetingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            greetingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),

            roleLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 6),
            roleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            roleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),

            syncButton.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 48),
            syncButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            syncButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),
            syncButton.heightAnchor.constraint(equalToConstant: 50),

            logoutButton.topAnchor.constraint(equalTo: syncButton.bottomAnchor, constant: 20),
            logoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        syncButton.addTarget(self,   action: #selector(manualSync), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logout),     for: .touchUpInside)
    }

    private func populateUser() {
        guard let user = AuthManager.shared.currentUser else { return }
        // Show what we have immediately
        greetingLabel.text = "Hello, \(user.name) 👋"
        roleLabel.text     = "Signed in as \(user.role.rawValue.capitalized)"

        // Then refresh from backend to get the latest role
        AuthManager.shared.fetchUserProfile(user: user) { [weak self] updatedUser in
            AuthManager.shared.currentUser = updatedUser
            DispatchQueue.main.async {
                self?.greetingLabel.text = "Hello, \(updatedUser.name) 👋"
                self?.roleLabel.text     = "Signed in as \(updatedUser.role.rawValue.capitalized)"
            }
        }
    }

    // MARK: - Actions
    @objc private func manualSync() {
        LoadingOverlay.show(in: view)
        HealthSyncManager.shared.requestPermissionsAndSync(daysBack: 30) { success in
            DispatchQueue.main.async {
                LoadingOverlay.hide()
                let msg = success ? "Sync complete!" : "Sync failed"
                let alert = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func logout() {
        LoadingOverlay.show(in: view)
        AuthManager.shared.logout(from: self) { [weak self] in
            DispatchQueue.main.async {
                LoadingOverlay.hide()
                // Go back to welcome screen
                let welcome = WelcomeViewController()
                welcome.modalPresentationStyle = .fullScreen
                self?.present(welcome, animated: true)
            }
        }
    }
}
