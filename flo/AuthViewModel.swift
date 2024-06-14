//
//  AuthViewModel.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import Foundation
import KeychainAccess

class AuthViewModel: ObservableObject {
  @Published var user: User?

  @Published var serverUrl: String = ""
  @Published var username: String = ""
  @Published var password: String = ""

  @Published var showAlert: Bool = false
  @Published var alertMessage: String = ""

  @Published var isLoggedIn: Bool = false

  static let shared = AuthViewModel()

  init() {
    do {
      if let jsonString = try KeychainManager.getAuthCreds(),
        let jsonData = jsonString.data(using: .utf8)
      {
        let data: UserAuth = try JSONDecoder().decode(UserAuth.self, from: jsonData)

        self.user = User(
          id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
          lastFMApiKey: data.lastFMApiKey)
        self.isLoggedIn = true
      }
    } catch {
      print("Error loading data from Keychain: \(error)")
    }
  }

  func login() {
    AuthService.shared.login(serverUrl: serverUrl, username: username, password: password) {
      result in
      switch result {
      case .success(let data):
        self.persistAuthData(data)

        DispatchQueue.main.async {
          self.isLoggedIn = true
          self.username = ""
          self.password = ""
          self.serverUrl = ""
        }

      case .failure(let error):
        DispatchQueue.main.async {
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

      UserDefaultsManager.removeObject(key: UserDefaultsKeys.serverURL)

      self.user = nil
      self.isLoggedIn = false
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

      self.user = User(
        id: data.id, username: data.username, name: data.name, isAdmin: data.isAdmin,
        lastFMApiKey: data.lastFMApiKey)
    } catch {
      print("Error saving data to Keychain: \(error)")
    }
  }
}
