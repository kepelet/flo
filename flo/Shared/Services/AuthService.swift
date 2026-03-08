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
  private var authMode: AuthMode = .standard
  private var iapAuthInfo: IAPAuthInfo?

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
    
    if authMode == .iap {
      iapAuthInfo = try? KeychainManager.getIAPAuthInfo()
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
    
    if key == "IAPJwt" {
      if let jwt = iapAuthInfo?.jwtAssertion {
        return jwt
      }
    }

    return ""
  }
  
  func getAuthMode() -> AuthMode {
    return authMode
  }
  
  func getIAPAuthInfo() -> IAPAuthInfo? {
    return iapAuthInfo
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
  
  func setIAPAuthInfo(_ info: IAPAuthInfo) {
    self.iapAuthInfo = info
    try? KeychainManager.setIAPAuthInfo(info)
  }
  
  func clearIAPAuthInfo() {
    self.iapAuthInfo = nil
    try? KeychainManager.removeIAPAuthInfo()
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
  
  func loginWithIAP(
    serverUrl: String,
    jwtAssertion: String,
    completion: @escaping (AuthResult<UserAuth>) -> Void
  ) {
    let serverBaseUrl = UserDefaultsManager.serverBaseURL
    let isServerBaseURLExist = serverBaseUrl != ""

    let url = "\(isServerBaseURLExist ? serverBaseUrl : serverUrl)\(API.NDEndpoint.loginIAP ?? "/auth/iap")"

    let parameters: [String: Any] = ["jwt": jwtAssertion]

    APIManager.shared.loginWithIAP(endpoint: url, parameters: parameters, jwtAssertion: jwtAssertion) {
      (response: DataResponse<UserAuth, AFError>) in
      switch response.result {
      case .success(let authResponse):
        let userEmail = self.extractEmailFromJWT(jwtAssertion)
        let userId = self.extractUserIdFromJWT(jwtAssertion)
        
        let iapInfo = IAPAuthInfo(
          jwtAssertion: jwtAssertion,
          userEmail: userEmail,
          userId: userId
        )
        
        self.setAuthMode(.iap)
        self.setIAPAuthInfo(iapInfo)
        
        completion(.success(authResponse))
        
      case .failure(let afError):
        ErrorHandler.handleFailure(afError, response: response) { result in
          LoggerStore.shared.storeMessage(
            label: "AuthService.loginWithIAP",
            level: .debug,
            message: response.debugDescription
          )
          completion(AuthResult(result: result))
        }
      }
    }
  }
    
  private func extractEmailFromJWT(_ jwt: String) -> String? {
    guard let payload = decodeJWTPayload(jwt),
          let email = payload["email"] as? String else {
      return nil
    }
    return email
  }
  
  private func extractUserIdFromJWT(_ jwt: String) -> String? {
    guard let payload = decodeJWTPayload(jwt),
          let userId = payload["sub"] as? String else {
      return nil
    }
    return userId
  }
  
  private func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
    let segments = jwt.components(separatedBy: ".")
    guard segments.count > 1 else { return nil }
    
    let payloadSegment = segments[1]
    
    var base64 = payloadSegment
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    let paddingLength = (4 - base64.count % 4) % 4
    base64 += String(repeating: "=", count: paddingLength)
    
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    
    return json
  }
}
