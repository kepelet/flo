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

    return UserDefaultsManager.requestLogs
      ? Alamofire.Session(eventMonitors: [NetworkLoggerEventMonitor()])
      : Alamofire.Session()
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

  func SubsonicEndpointDownload(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString,
    completion: @escaping (Result<Data, AFError>) -> Void
  ) {

    // FIXME: refactor getCreds(key: "subsonicToken")
    let url =
      "\(UserDefaultsManager.serverBaseURL)\(endpoint)\(AuthService.shared.getCreds(key: "subsonicToken"))"

    session.request(
      url, method: method, parameters: parameters, encoding: encoding
    )
    .validate(statusCode: 200..<500)
    .responseData { response in
      switch response.result {
      case .success(let data):
        completion(.success(data))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
