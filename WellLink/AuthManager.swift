// AuthManager.swift
// Singleton that owns the Auth0 session: login, logout, token refresh,
// role update, and exposing the current user to the rest of the app.

import Foundation
import UIKit
import Auth0
import JWTDecode

// MARK: - User model
struct WellLinkUser {
    let id: String          // Auth0 "sub" — e.g. "auth0|64f..."
    let email: String
    let name: String
    let pictureURL: URL?
    var role: UserRole
    var idToken: String     // decoded for user claims
    var accessToken: String // sent to your backend as Bearer token
}

enum UserRole: String, CaseIterable {
    case user   = "user"
    case doctor = "doctor"
}

// MARK: - AuthManager
final class AuthManager {

    static let shared = AuthManager()
    private init() {}

    // Publicly settable so ViewControllers can update the role after backend fetch
    var currentUser: WellLinkUser?

    // Convenience
    var isLoggedIn: Bool { currentUser != nil }

    // Credentials manager persists tokens in the Keychain automatically
    private let credentialsManager = CredentialsManager(
        authentication: Auth0.authentication(
            clientId: Auth0Config.clientId,
            domain:   Auth0Config.domain
        )
    )

    // MARK: - Login (universal login — handles Google & Apple inside Auth0)
    /// Call this for both "Log in" and "Sign up" — pass `screenHint: "signup"` for sign-up.
    func login(
        role:       UserRole,
        screenHint: String = "login",       // "login" or "signup"
        from:       UIViewController,
        completion: @escaping (Result<WellLinkUser, Error>) -> Void
    ) {
        Auth0
            .webAuth(clientId: Auth0Config.clientId, domain: Auth0Config.domain)
            .scope(Auth0Config.scopes)
            .audience(Auth0Config.audience)
            .parameters([
                "screen_hint": screenHint,
                "state": role.rawValue
            ])
            .redirectURL(URL(string: Auth0Config.redirectURI)!)
            .start { [weak self] result in
                switch result {
                case .success(let credentials):
                    self?.credentialsManager.store(credentials: credentials)
                    self?.buildUser(from: credentials, initialRole: role) { userResult in
                        switch userResult {
                        case .success(let user):
                            self?.currentUser = user
                            // Tell backend about the role (new sign-ups)
                            if screenHint == "signup" {
                                self?.syncRoleToBackend(user: user) { _ in }
                            }
                            completion(.success(user))
                        case .failure(let err):
                            completion(.failure(err))
                        }
                    }
                case .failure(let err):
                    completion(.failure(err))
                }
            }
    }

    // MARK: - Logout
    func logout(from: UIViewController, completion: @escaping () -> Void) {
        Auth0
            .webAuth(clientId: Auth0Config.clientId, domain: Auth0Config.domain)
            .redirectURL(URL(string: Auth0Config.logoutURI)!)
            .clearSession { [weak self] result in
                self?.credentialsManager.clear()
                self?.currentUser = nil
                completion()
            }
    }

    // MARK: - Silent restore on app launch
    func restoreSession(completion: @escaping (Bool) -> Void) {
        // hasValid() checks the Keychain for a non-expired token
        guard credentialsManager.hasValid() else {
            credentialsManager.clear()   // wipe any stale/partial tokens
            completion(false)
            return
        }
        credentialsManager.credentials { [weak self] result in
            switch result {
            case .success(let credentials):
                // Extra guard: make sure idToken is not empty
                guard !credentials.idToken.isEmpty else {
                    self?.credentialsManager.clear()
                    completion(false)
                    return
                }
                self?.buildUser(from: credentials, initialRole: .user) { userResult in
                    if case .success(let user) = userResult {
                        self?.currentUser = user
                        completion(true)
                    } else {
                        self?.credentialsManager.clear()
                        completion(false)
                    }
                }
            case .failure:
                self?.credentialsManager.clear()
                completion(false)
            }
        }
    }

    // MARK: - Get a fresh access token (for backend calls)
    func freshAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
        credentialsManager.credentials { result in
            switch result {
            case .success(let c): completion(.success(c.accessToken))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    // MARK: - Get a fresh ID token (for decoding claims)
    func freshIDToken(completion: @escaping (Result<String, Error>) -> Void) {
        credentialsManager.credentials { result in
            switch result {
            case .success(let c): completion(.success(c.idToken))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    // MARK: - Fetch user profile from backend GET /api/users/:userId
    func fetchUserProfile(user: WellLinkUser, completion: @escaping (WellLinkUser) -> Void) {
        // URL-encode the userId (Auth0 sub contains "|" which must be encoded)
        let encodedId = user.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user.id
        guard let url = URL(string: "\(Auth0Config.backendBase)/api/users/\(encodedId)") else {
            completion(user); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, response, error in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roleString = json["role"] as? String,
                  let role = UserRole(rawValue: roleString) else {
                // Backend call failed — return user as-is
                completion(user)
                return
            }
            var updated = user
            updated.role = role
            completion(updated)
        }.resume()
    }

    // MARK: - Update role on backend POST /api/users/:userId/role
    func syncRoleToBackend(user: WellLinkUser, completion: @escaping (Bool) -> Void) {
        let encodedId = user.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user.id
        guard let url = URL(string: "\(Auth0Config.backendBase)/api/users/\(encodedId)/role") else {
            completion(false); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["role": user.role.rawValue])

        URLSession.shared.dataTask(with: req) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            completion(ok)
        }.resume()
    }

    // MARK: - Private helpers
    private func buildUser(
        from credentials: Credentials,
        initialRole: UserRole,
        completion: @escaping (Result<WellLinkUser, Error>) -> Void
    ) {
        guard let jwt   = try? JWTDecode.decode(jwt: credentials.idToken),
              let sub   = jwt.subject,
              let email = jwt["email"].string else {
            completion(.failure(AuthError.invalidToken))
            return
        }

        let name    = jwt["name"].string ?? email
        let picture = jwt["picture"].string.flatMap { URL(string: $0) }
        let role    = UserRole(rawValue: jwt["https://welllink.app/role"].string ?? "") ?? initialRole

        var user = WellLinkUser(
            id: sub, email: email, name: name, pictureURL: picture,
            role: role, idToken: credentials.idToken, accessToken: credentials.accessToken
        )

        // Fetch the real role from your backend
        fetchUserProfile(user: user) { updatedUser in
            completion(.success(updatedUser))
        }
    }

    enum AuthError: LocalizedError {
        case invalidToken
        var errorDescription: String? { "Could not read the authentication token." }
    }
}
