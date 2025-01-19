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
    // TODO: invalidate authz token somewhere here
    do {
      if let jsonString = try KeychainManager.getAuthCreds(),
        let jsonData = jsonString.data(using: .utf8)
      {
        let data: UserAuth = try JSONDecoder().decode(UserAuth.self, from: jsonData)

        self.serverUrl = UserDefaultsManager.serverBaseURL
        self.username = data.username

        if UserDefaultsManager.saveLoginInfo {
          do {
            self.password = try KeychainManager.getAuthPassword() ?? ""
          } catch {
            print("Error loading password from Keychain: \(error)")
          }

          self.login()
        } else {

          self.user = UserAuth(
            id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
            lastFMApiKey: data.lastFMApiKey)
          self.isLoggedIn = true
        }
      }
    } catch {
      print("Error loading data from Keychain: \(error)")
    }
  }

  func login() {
    isSubmitting = true

    AuthService.shared.login(serverUrl: serverUrl, username: username, password: password) {
      result in
      switch result {
      case .success(let data):
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

        DispatchQueue.main.async {
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

      self.destroySavedPassword()

      UserDefaultsManager.removeObject(key: UserDefaultsKeys.serverURL)

      self.user = nil
      self.isLoggedIn = false
    } catch let error {
      print("error>>>>> \(error)")
    }
  }

  func destroySavedPassword() {
    do {
      try KeychainManager.removeAuthPassword()

      UserDefaultsManager.saveLoginInfo = false
      UserDefaultsManager.removeObject(key: UserDefaultsKeys.saveLoginInfo)
    } catch let error {
      print("error>>>>> \(error)")
    }
  }

  func persistAuthData(_ data: UserAuth) {
    do {
      let jsonData = try JSONEncoder().encode(data)
      let jsonString = String(data: jsonData, encoding: .utf8)!

      try KeychainManager.setAuthCreds(newValue: jsonString)

      AuthService.shared.setCreds(data)
      UserDefaultsManager.serverBaseURL = self.serverUrl

      self.user = UserAuth(
        id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
        lastFMApiKey: data.lastFMApiKey)
    } catch {
      print("Error saving data to Keychain: \(error)")
    }
  }
}
