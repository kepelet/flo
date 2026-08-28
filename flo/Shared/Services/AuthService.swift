//
//  AuthService.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import Alamofire
import Foundation
import Pulse

enum IAPSessionCheckResult {
  case valid
  case invalid(String)
  case unreachable
}

class AuthService {
  static let shared = AuthService()

  private var NDToken: String?
  private var subsonicParams: String?
  private var authMode: AuthMode = .standard

  private init() {
    if let jsonString = try? KeychainManager.getAuthCreds(),
      let jsonData = jsonString.data(using: .utf8)
    {
      if let data: UserAuth = try? JSONDecoder().decode(UserAuth.self, from: jsonData) {
        NDToken = data.token
        subsonicParams =
          "?u=\(data.username)&t=\(data.subsonicToken)&s=\(data.subsonicSalt)&v=\(AppMeta.subsonicApiVersion)&c=\(AppMeta.name)&f=json"
      }
    }

    if let mode = try? KeychainManager.getAuthMode() {
      authMode = mode
    }
  }

  func getCreds(key: String = "") -> String {
    if key == "NDToken" {
      if let token = NDToken {
        return token
      }
    }

    if key == "subsonicToken" {
      if let token = subsonicParams {
        return token
      }
    }

    return ""
  }

  func getAuthMode() -> AuthMode {
    return authMode
  }

  func setCreds(_ data: UserAuth) {
    let subsonicParams =
      "?u=\(data.username)&t=\(data.subsonicToken)&s=\(data.subsonicSalt)&v=\(AppMeta.subsonicApiVersion)&c=\(AppMeta.name)&f=json"

    self.NDToken = data.token
    self.subsonicParams = subsonicParams
  }

  func setAuthMode(_ mode: AuthMode) {
    self.authMode = mode
    try? KeychainManager.setAuthMode(mode)
  }

  func login(
    serverUrl: String, username: String, password: String,
    completion: @escaping (AuthResult<UserAuth>) -> Void
  ) {
    let serverBaseUrl = UserDefaultsManager.serverBaseURL
    let isServerBaseURLExist = serverBaseUrl != ""

    let url = "\(isServerBaseURLExist ? serverBaseUrl : serverUrl)\(API.NDEndpoint.login)"

    let parameters: [String: Any] = ["username": username, "password": password]

    APIManager.shared.login(endpoint: url, parameters: parameters) {
      (response: DataResponse<UserAuth, AFError>) in
      switch response.result {
      case .success(let authResponse):
        // Set auth mode to standard for username/password login
        self.setAuthMode(.standard)
        completion(.success(authResponse))
      case .failure(let afError):
        ErrorHandler.handleFailure(afError, response: response) { result in
          // FIXME: temporary solution
          let debugResponse = response.debugDescription.replacingOccurrences(
            of: #"(?s)"password"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#,
            with: #""password":"[REDACTED]""#,
            options: .regularExpression
          )

          // FIXME: move to general Logger
          LoggerStore.shared.storeMessage(
            label: "AuthService.login",
            level: .debug,
            message: debugResponse
          )
          completion(AuthResult(result: result))
        }
      }
    }
  }

  /// Lightweight ND JWT liveness check for standard auth.
  /// Standard mode previously never revalidated (ghost session when ND token
  /// expires but Subsonic token still returns 200 for getScanStatus). Hits
  /// `GET /api/album?_start=0&_end=1` with Bearer token and maps 401/403 →
  /// .invalid so the caller can clear isLoggedIn.
  func verifyNDSession(
    serverUrl: String, token: String,
    completion: @escaping (IAPSessionCheckResult) -> Void
  ) {
    guard !serverUrl.isEmpty, !token.isEmpty,
      let url = URL(string: "\(serverUrl)/api/album?_start=0&_end=1")
    else {
      completion(.unreachable)
      return
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: API.NDAuthHeader)
    request.timeoutInterval = 10
    URLSession.shared.dataTask(with: request) { _, response, _ in
      guard let http = response as? HTTPURLResponse else {
        completion(.unreachable)
        return
      }
      if http.statusCode == 401 || http.statusCode == 403 {
        completion(.invalid("Session expired"))
      } else if (200..<300).contains(http.statusCode) {
        completion(.valid)
      } else {
        completion(.unreachable)
      }
    }.resume()
  }

  func verifySubsonicAccess(
    _ userAuth: UserAuth,
    serverUrl: String,
    completion: @escaping (IAPSessionCheckResult) -> Void
  ) {
    guard var components = URLComponents(string: "\(serverUrl)/rest/ping") else {
      completion(.unreachable)
      return
    }

    components.queryItems = [
      URLQueryItem(name: "u", value: userAuth.username),
      URLQueryItem(name: "t", value: userAuth.subsonicToken),
      URLQueryItem(name: "s", value: userAuth.subsonicSalt),
      URLQueryItem(name: "v", value: AppMeta.subsonicApiVersion),
      URLQueryItem(name: "c", value: AppMeta.name),
      URLQueryItem(name: "f", value: "json"),
    ]

    guard let url = components.url else {
      completion(.unreachable)
      return
    }

    URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, _ in
      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.unreachable)
        return
      }

      if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
        completion(.invalid("Authentication rejected by the server."))
        return
      }

      guard let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let subsonicResponse = json["subsonic-response"] as? [String: Any],
        let status = subsonicResponse["status"] as? String
      else {
        completion(.unreachable)
        return
      }

      if status == "ok" {
        completion(.valid)
      } else {
        let subsonicError = subsonicResponse["error"] as? [String: Any]
        let message =
          subsonicError?["message"] as? String ?? "Something went wrong with IAP Authentication."
        completion(.invalid(message))
      }
    }.resume()
  }
}
