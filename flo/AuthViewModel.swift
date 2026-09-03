//
//  AuthViewModel.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import Foundation
import KeychainAccess

class AuthViewModel: ObservableObject {
  @Published var user: UserAuth?

  @Published var serverUrl: String = "" {
    didSet {
      validateURL()
    }
  }

  @Published var username: String = ""
  @Published var password: String = ""

  @Published var showAlert: Bool = false
  @Published var alertMessage: String = ""
  @Published var extraMessage: String = ""
  @Published var experimentalSaveLoginInfo: Bool = false

  @Published var isSubmitting: Bool = false
  @Published var isLoggedIn: Bool = false

  @Published var authMode: AuthMode = .standard

  static let shared = AuthViewModel()

  private func validateURL() {
    if serverUrl.lowercased().hasPrefix("http://") {
      extraMessage =
        "http:// is only supported within private IP ranges: 192.168.0.0/16, 10.0.0.0/8, and 172.16.0.0/12 — learn more at https://dub.sh/flo-ats"
    } else {
      extraMessage = ""
    }
  }

  init() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleSessionExpired), name: .sessionExpired, object: nil)

    do {
      if let jsonString = try KeychainManager.getAuthCreds(),
        let jsonData = jsonString.data(using: .utf8)
      {
        let data: UserAuth = try JSONDecoder().decode(UserAuth.self, from: jsonData)

        serverUrl = UserDefaultsManager.serverBaseURL
        username = data.username

        authMode = AuthService.shared.getAuthMode()

        if authMode == .iap {
          user = UserAuth(
            id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
            lastFMApiKey: data.lastFMApiKey
          )
          AuthService.shared.setCreds(data)
          isLoggedIn = true

          AuthService.shared.verifySubsonicAccess(data, serverUrl: serverUrl) { result in
            if case .invalid = result {
              DispatchQueue.main.async {
                self.logout()
              }
            }
          }
        } else if UserDefaultsManager.saveLoginInfo {
          do {
            password = try KeychainManager.getAuthPassword() ?? ""
          } catch {
            print("Error loading password from Keychain: \(error)")
          }

          login()
        } else {
          user = UserAuth(
            id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
            lastFMApiKey: data.lastFMApiKey
          )
          AuthService.shared.setCreds(data)
          isLoggedIn = true

          // Standard auth was previously never revalidated (only IAP via
          // verifySubsonicAccess in 7a9f844). A stale ND JWT therefore
          // produced a ghost isLoggedIn=true while every /api/* returned
          // 401. Verify ND token in background; on 401/403 clear the
          // session so UI flips to .expired / login sheet instead of
          // hanging empty.
          AuthService.shared.verifyNDSession(serverUrl: serverUrl, token: data.token) {
            result in
            if case .invalid = result {
              DispatchQueue.main.async {
                self.logout()
              }
            }
          }
        }
      }
    } catch {
      print("Error loading data from Keychain: \(error)")
    }
  }

  @objc private func handleSessionExpired() {
    logout()
  }

  func login() {
    isSubmitting = true

    AuthService.shared.login(serverUrl: serverUrl, username: username, password: password) {
      result in
      switch result {
      case .success(let data):
        // persistAuthData mutates @Published state ("user"), so make sure the
        // whole success path runs on the main actor regardless of which queue
        // Alamofire delivered the response on.
        DispatchQueue.main.async {
          self.persistAuthData(data)

          if self.experimentalSaveLoginInfo {
            do {
              try KeychainManager.setAuthPassword(newValue: self.password)
              UserDefaultsManager.saveLoginInfo = true

              self.experimentalSaveLoginInfo = false
            } catch {
              print("error saving password to Keychain: \(error)")
            }
          }

          self.isSubmitting = false
          self.isLoggedIn = true
          self.username = ""
          self.password = ""
          self.serverUrl = ""
        }

      case .failure(let error):
        DispatchQueue.main.async {
          self.isSubmitting = false

          switch error {
          case .server(let message):
            self.alertMessage = message

          case .sessionExpired:
            self.alertMessage = "Session expired. Please log in again."

          case .unknown:
            self.alertMessage = "Unknown error ocurred"
          }

          self.showAlert = true
        }
      }
    }
  }

  // TODO: how to deal with "last playing" data?
  func logout() {
    do {
      try KeychainManager.removeAuthCreds()

      destroySavedPassword()

      if authMode == .iap {
        try? KeychainManager.removeAuthMode()
      }

      UserDefaultsManager.removeObject(key: UserDefaultsKeys.serverURL)

      user = nil
      isLoggedIn = false
      authMode = .standard
    } catch {
      print("error>>>>> \(error)")
    }
  }

  func destroySavedPassword() {
    do {
      try KeychainManager.removeAuthPassword()

      UserDefaultsManager.saveLoginInfo = false
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.saveLoginInfo)
    } catch {
      print("error>>>>> \(error)")
    }
  }

  func persistAuthData(_ data: UserAuth) {
    do {
      let jsonData = try JSONEncoder().encode(data)
      let jsonString = String(data: jsonData, encoding: .utf8)!

      do {
        try KeychainManager.setAuthCreds(newValue: jsonString)
      } catch {
        print("Error saving auth creds to Keychain: \(error)")
      }

      AuthService.shared.setCreds(data)
      UserDefaultsManager.serverBaseURL = serverUrl

      user = UserAuth(
        id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
        lastFMApiKey: data.lastFMApiKey
      )
    } catch {
      print("Error encoding auth data: \(error)")
    }
  }

}
