//
//  AuthService.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import Alamofire
import Foundation
import Pulse

class AuthService {
  static let shared = AuthService()

  private var NDToken: String?
  private var subsonicParams: String?

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

  func setCreds(_ data: UserAuth) {
    let subsonicParams =
      "?u=\(data.username)&t=\(data.subsonicToken)&s=\(data.subsonicSalt)&v=\(AppMeta.subsonicApiVersion)&c=\(AppMeta.name)&f=json"

    self.NDToken = data.token
    self.subsonicParams = subsonicParams
  }

  func login(
    serverUrl: String, username: String, password: String,
    completion: @escaping (AuthResult<UserAuth>) -> Void
  ) {
    let isServerBaseURLExist = UserDefaultsManager.serverBaseURL != ""
    let url = "\(isServerBaseURLExist ? "" : serverUrl)\(API.NDEndpoint.login)"
    let parameters: [String: Any] = ["username": username, "password": password]

    APIManager.shared.NDEndpointRequest(
      endpoint: url, method: .post, parameters: parameters, encoding: JSONEncoding.default
    ) { (response: DataResponse<UserAuth, AFError>) in
      switch response.result {
      case .success(let authResponse):
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
}
