//
//  APIManager.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import Alamofire
import Foundation
import Pulse

// TODO: refactor this
struct NetworkLoggerEventMonitor: EventMonitor {
  var logger: NetworkLogger = .shared

  func request(_ request: Request, didCreateTask task: URLSessionTask) {
    logger.logTaskCreated(task)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    logger.logDataTask(dataTask, didReceive: data)
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    logger.logTask(task, didFinishCollecting: metrics)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    logger.logTask(task, didCompleteWithError: error)
  }
}

class APIManager {
  static let shared = APIManager()

  private(set) var session: Alamofire.Session

  private init() {
    session = Self.createSession()
  }

  /// Test-only hook: extra URLProtocol subclasses to register on the session.
  static var extraProtocolClasses: [AnyClass] = []

  private static func createSession() -> Session {
    LoggerStore.shared.removeAll()

    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30

    if !extraProtocolClasses.isEmpty {
      configuration.protocolClasses = extraProtocolClasses + (configuration.protocolClasses ?? [])
    }

    let retrier = RetryPolicy(retryLimit: 3)
    let monitor = NetworkLoggerEventMonitor()

    return Alamofire.Session(
      configuration: configuration, interceptor: retrier,
      eventMonitors: UserDefaultsManager.enableDebug ? [monitor] : [])
  }

  func reconfigureSession() {
    session = Self.createSession()
  }

  func NDEndpointRequest<T: Decodable>(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString, timeout: TimeInterval? = nil,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {
    let authSession = AuthService.shared.sessionSnapshot()
    let token = authSession.ndToken

    let url = "\(UserDefaultsManager.serverBaseURL)\(endpoint)"
    let headers: HTTPHeaders = [API.NDAuthHeader: "Bearer \(token)"]

    session.request(
      url, method: method, parameters: parameters, encoding: encoding, headers: headers,
      requestModifier: { request in
        if let timeout = timeout {
          request.timeoutInterval = timeout
        }
      }
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: T.self) { response in
      Self.notifySessionExpiredIfNeeded(
        response: response.response, error: response.error, authSession: authSession)
      completion(response)
    }
  }

  func SubsonicEndpointRequest<T: Decodable>(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString, timeout: TimeInterval? = nil,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {

    // FIXME: refactor getCreds(key: "subsonicToken")
    let authSession = AuthService.shared.sessionSnapshot()
    let url =
      "\(UserDefaultsManager.serverBaseURL)\(endpoint)\(authSession.subsonicCredentials)"

    session.request(
      url, method: method, parameters: parameters, encoding: encoding,
      requestModifier: { request in
        if let timeout = timeout {
          request.timeoutInterval = timeout
        }
      }
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: T.self) { response in
      // Subsonic servers report stale/invalid credentials as HTTP 200 with
      // `subsonic-response.status == "failed"` (error code 40/41) instead of
      // a 401, so a plain status-code check never sees them. Detect it so
      // the ghost-session recovery fires for Subsonic surfaces too.
      Self.notifySessionExpiredIfNeeded(
        response: response.response, error: response.error, authSession: authSession,
        isAuthFailed: Self.isSubsonicAuthFailure(data: response.data))
      completion(response)
    }
  }

  // FIXME: refactor later
  func SubsonicEndpointDownloadNew(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString,
    progressUpdate: ((Double) -> Void)?,
    completion: @escaping (Result<URL, AFError>) -> Void
  ) -> DownloadRequest {

    // FIXME: refactor getCreds(key: "subsonicToken")
    let url =
      "\(UserDefaultsManager.serverBaseURL)\(endpoint)\(AuthService.shared.getCreds(key: "subsonicToken"))"

    let authSession = AuthService.shared.sessionSnapshot()

    return session.download(
      url, method: method, parameters: parameters, encoding: encoding,
      requestModifier: { $0.timeoutInterval = 60 }
    )
    .downloadProgress { progressValue in
      progressUpdate?(progressValue.fractionCompleted * 100)
    }
    .validate()
    .responseURL { response in
      Self.notifySessionExpiredIfNeeded(
        response: response.response, error: response.error, authSession: authSession)
      switch response.result {
      case .success(let fileURL):
        completion(.success(fileURL))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func SubsonicEndpointDownload(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString,
    completion: @escaping (Result<URL, AFError>) -> Void
  ) {

    // FIXME: refactor getCreds(key: "subsonicToken")
    let url =
      "\(UserDefaultsManager.serverBaseURL)\(endpoint)\(AuthService.shared.getCreds(key: "subsonicToken"))"

    let authSession = AuthService.shared.sessionSnapshot()

    session.download(
      url, method: method, parameters: parameters, encoding: encoding,
      requestModifier: { $0.timeoutInterval = 60 }
    )
    .validate()
    .responseURL { response in
      Self.notifySessionExpiredIfNeeded(
        response: response.response, error: response.error, authSession: authSession)
      switch response.result {
      case .success(let fileURL):
        completion(.success(fileURL))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}

extension APIManager {
  /// Posts .sessionExpired when the underlying HTTP response is 401/403.
  /// Centralizes ghost-session recovery so NDEndpoint + Subsonic callers do
  /// not need to duplicate status-code inspection.
  static func notifySessionExpiredIfNeeded(
    response: HTTPURLResponse?, error: AFError?, authSession: AuthSessionSnapshot,
    isAuthFailed: Bool = false
  ) {
    if !isAuthFailed {
      let status = response?.statusCode ?? error?.responseCode
      guard let code = status, code == 401 || code == 403 else { return }
    }
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .sessionExpired, object: authSession)
    }
  }

  /// True when a Subsonic-shaped body carries an authentication failure:
  /// `status == "failed"` with error code 40 (wrong username/password) or 41
  /// (token auth unsupported). Other failure codes (missing params, version
  /// mismatch, folder not found, …) are not session problems and must not
  /// log the user out.
  fileprivate static func isSubsonicAuthFailure(data: Data?) -> Bool {
    guard let data = data,
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let subsonic = json["subsonic-response"] as? [String: Any],
      let status = subsonic["status"] as? String, status != "ok"
    else {
      return false
    }

    guard let error = subsonic["error"] as? [String: Any], let code = error["code"] as? Int
    else {
      return false
    }

    return code == 40 || code == 41
  }

  func login<T: Decodable>(
    endpoint: String, parameters: Parameters?,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {
    session.request(
      endpoint,
      method: .post,
      parameters: parameters,
      encoding: JSONEncoding.default,
      requestModifier: { request in
        request.timeoutInterval = 10
      }
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: T.self) { response in
      completion(response)
    }
  }
  func externalRequest<T: Decodable>(
    url: String,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.queryString,
    headers: HTTPHeaders? = nil,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {
    session.request(
      url, method: method, parameters: parameters, encoding: encoding, headers: headers
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: T.self) { response in
      completion(response)
    }
  }
}

extension Notification.Name {
  static let sessionExpired = Notification.Name("flo.sessionExpired")
}
