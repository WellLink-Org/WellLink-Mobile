// WelcomeViewController.swift
// Shown when the user is not authenticated.
// Mirrors your web signup form: role picker + "Sign up with Google/Apple/Email"

import UIKit

final class WelcomeViewController: UIViewController {

    // MARK: - State
    private var selectedRole: UserRole = .user

    // MARK: - UI
    private let scrollView   = UIScrollView()
    private let contentView  = UIView()

    private let logoView     = LogoView()
    private let titleLabel   = UILabel()
    private let subtitleLabel = UILabel()
    private let roleControl  = UISegmentedControl(items: ["Patient", "Doctor"])
    private let roleTitleLabel = UILabel()

    private let googleButton = SocialLoginButton(provider: .google)
    private let appleButton  = SocialLoginButton(provider: .apple)

    private let dividerView  = DividerView(label: "or sign up with email")
    private let emailButton  = PrimaryButton(title: "Sign up with Email")
    private let loginPrompt  = FooterLinkLabel(
        text: "Already have an account? ",
        linkText: "Log in"
    )

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        buildLayout()
        styleViews()
        wireActions()
    }

    // MARK: - Layout
    private func buildLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        [logoView, titleLabel, subtitleLabel,
         roleTitleLabel, roleControl,
         googleButton, appleButton,
         dividerView, emailButton, loginPrompt
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let p: CGFloat = 24

        NSLayoutConstraint.activate([
            // Scroll
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Logo
            logoView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
            logoView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Title
            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),

            // Role label
            roleTitleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            roleTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),

            // Role picker
            roleControl.topAnchor.constraint(equalTo: roleTitleLabel.bottomAnchor, constant: 8),
            roleControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            roleControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),
            roleControl.heightAnchor.constraint(equalToConstant: 44),

            // Google
            googleButton.topAnchor.constraint(equalTo: roleControl.bottomAnchor, constant: 24),
            googleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            googleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),
            googleButton.heightAnchor.constraint(equalToConstant: 50),

            // Apple
            appleButton.topAnchor.constraint(equalTo: googleButton.bottomAnchor, constant: 12),
            appleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            appleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),
            appleButton.heightAnchor.constraint(equalToConstant: 50),

            // Divider
            dividerView.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 20),
            dividerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            dividerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),

            // Email button
            emailButton.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 20),
            emailButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: p),
            emailButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -p),
            emailButton.heightAnchor.constraint(equalToConstant: 50),

            // Footer
            loginPrompt.topAnchor.constraint(equalTo: emailButton.bottomAnchor, constant: 20),
            loginPrompt.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loginPrompt.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }

    private func styleViews() {
        titleLabel.text          = "Create your account"
        titleLabel.font          = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        subtitleLabel.text          = "Join WellLink to sync your health data and get personalised AI insights."
        subtitleLabel.font          = .systemFont(ofSize: 15)
        subtitleLabel.textColor     = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        roleTitleLabel.text      = "I am a…"
        roleTitleLabel.font      = .systemFont(ofSize: 14, weight: .medium)
        roleTitleLabel.textColor = .label

        roleControl.selectedSegmentIndex = 0   // "Patient"
        roleControl.selectedSegmentTintColor = UIColor(red: 0.24, green: 0.62, blue: 0.33, alpha: 1)
        roleControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    }

    // MARK: - Actions
    private func wireActions() {
        roleControl.addTarget(self, action: #selector(roleChanged), for: .valueChanged)
        googleButton.addTarget(self, action: #selector(signUpGoogle), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(signUpApple),  for: .touchUpInside)
        emailButton.addTarget(self,  action: #selector(signUpEmail), for: .touchUpInside)
        loginPrompt.onLinkTap = { [weak self] in self?.goToLogin() }
    }

    @objc private func roleChanged() {
        selectedRole = roleControl.selectedSegmentIndex == 0 ? .user : .doctor
    }

    @objc private func signUpGoogle() { triggerLogin(screenHint: "signup") }
    @objc private func signUpApple()  { triggerLogin(screenHint: "signup") }   // Auth0 routes to Apple inside universal login
    @objc private func signUpEmail()  { triggerLogin(screenHint: "signup") }

    private func triggerLogin(screenHint: String) {
        LoadingOverlay.show(in: view)
        AuthManager.shared.login(role: selectedRole, screenHint: screenHint, from: self) { [weak self] result in
            DispatchQueue.main.async {
                LoadingOverlay.hide()
                switch result {
                case .success:
                    self?.navigateToMain()
                case .failure(let err):
                    self?.showError(err.localizedDescription)
                }
            }
        }
    }

    private func goToLogin() {
        LoadingOverlay.show(in: view)
        AuthManager.shared.login(role: selectedRole, screenHint: "login", from: self) { [weak self] result in
            DispatchQueue.main.async {
                LoadingOverlay.hide()
                switch result {
                case .success: self?.navigateToMain()
                case .failure(let err): self?.showError(err.localizedDescription)
                }
            }
        }
    }

    private func navigateToMain() {
        let vc = MainTabBarController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
