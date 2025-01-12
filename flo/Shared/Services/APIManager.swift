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

  private static func createSession() -> Session {
    LoggerStore.shared.removeAll()

    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30

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
    encoding: ParameterEncoding = URLEncoding.queryString,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {
    let token: String = AuthService.shared.getCreds(key: "NDToken")

    let url = "\(UserDefaultsManager.serverBaseURL)\(endpoint)"
    let headers: HTTPHeaders = [API.NDAuthHeader: "Bearer \(token)"]

    session.request(
      url, method: method, parameters: parameters, encoding: encoding, headers: headers
    )
    .validate(statusCode: 200..<500)
    .responseDecodable(of: T.self) { response in
      completion(response)
    }
  }

  func SubsonicEndpointRequest<T: Decodable>(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {

    // FIXME: refactor getCreds(key: "subsonicToken")
    let url =
      "\(UserDefaultsManager.serverBaseURL)\(endpoint)\(AuthService.shared.getCreds(key: "subsonicToken"))"

    session.request(
      url, method: method, parameters: parameters, encoding: encoding
    )
    .validate(statusCode: 200..<500)
    .responseDecodable(of: T.self) { response in
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

    return session.download(
      url, method: method, parameters: parameters, encoding: encoding,
      requestModifier: { $0.timeoutInterval = 60 }
    )
    .downloadProgress { progressValue in
      progressUpdate?(progressValue.fractionCompleted * 100)
    }
    .validate()
    .responseURL { response in
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

    session.download(
      url, method: method, parameters: parameters, encoding: encoding,
      requestModifier: { $0.timeoutInterval = 60 }
    )
    .validate()
    .responseURL { response in
      switch response.result {
      case .success(let fileURL):
        completion(.success(fileURL))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
