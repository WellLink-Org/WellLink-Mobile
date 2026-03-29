// ProfileViewController.swift
// Shows the logged-in user's info and lets them update their role.

import UIKit

final class ProfileViewController: UIViewController {

    private let nameLabel   = UILabel()
    private let emailLabel  = UILabel()
    private let idLabel     = UILabel()
    private let roleControl = UISegmentedControl(items: ["Patient", "Doctor"])
    private let saveButton  = PrimaryButton(title: "Save Role")
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        buildLayout()
        populateUser()
        refreshFromBackend()
    }

    private func refreshFromBackend() {
        guard let user = AuthManager.shared.currentUser else { return }
        AuthManager.shared.fetchUserProfile(user: user) { [weak self] updatedUser in
            AuthManager.shared.currentUser = updatedUser
            DispatchQueue.main.async {
                self?.nameLabel.text  = updatedUser.name
                self?.emailLabel.text = updatedUser.email
                self?.idLabel.text    = "ID: \(updatedUser.id)"
                self?.roleControl.selectedSegmentIndex = updatedUser.role == .user ? 0 : 1
            }
        }
    }

    private func buildLayout() {
        let stack = UIStackView(
            arrangedSubviews: [nameLabel, emailLabel, idLabel,
                               roleSectionLabel(), roleControl,
                               saveButton, statusLabel]
        )
        stack.axis         = .vertical
        stack.spacing      = 12
        stack.alignment    = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        [nameLabel, emailLabel, idLabel, statusLabel].forEach {
            $0.font          = .systemFont(ofSize: 15)
            $0.textColor     = .secondaryLabel
            $0.numberOfLines = 0
        }
        nameLabel.font  = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = .label

        statusLabel.textAlignment = .center
        statusLabel.textColor     = .systemGreen

        roleControl.selectedSegmentTintColor = UIColor(red: 0.24, green: 0.62, blue: 0.33, alpha: 1)
        roleControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)

        saveButton.addTarget(self, action: #selector(saveRole), for: .touchUpInside)
    }

    private func roleSectionLabel() -> UILabel {
        let l = UILabel()
        l.text      = "My role"
        l.font      = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .label
        return l
    }

    private func populateUser() {
        guard let user = AuthManager.shared.currentUser else { return }
        nameLabel.text  = user.name
        emailLabel.text = user.email
        idLabel.text    = "ID: \(user.id)"
        roleControl.selectedSegmentIndex = user.role == .user ? 0 : 1
    }

    @objc private func saveRole() {
        guard var user = AuthManager.shared.currentUser else { return }
        let newRole: UserRole = roleControl.selectedSegmentIndex == 0 ? .user : .doctor
        user.role = newRole

        statusLabel.text = "Saving…"
        AuthManager.shared.syncRoleToBackend(user: user) { [weak self] success in
            DispatchQueue.main.async {
                self?.statusLabel.text = success ? "Role saved ✓" : "Save failed — try again"
                self?.statusLabel.textColor = success ? .systemGreen : .systemRed
            }
        }
    }
}
