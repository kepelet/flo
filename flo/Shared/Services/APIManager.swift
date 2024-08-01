//
//  APIManager.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import Alamofire
import Foundation

class APIManager {
  static let shared = APIManager()

  func NDEndpointRequest<T: Decodable>(
    endpoint: String, method: HTTPMethod = .get, parameters: Parameters?,
    encoding: ParameterEncoding = URLEncoding.queryString,
    completion: @escaping (DataResponse<T, AFError>) -> Void
  ) {
    let token: String = AuthService.shared.getCreds(key: "NDToken")

    let url = "\(UserDefaultsManager.serverBaseURL)\(endpoint)"
    let headers: HTTPHeaders = [API.NDAuthHeader: "Bearer \(token)"]

    AF.request(
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

    AF.request(
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

    AF.request(
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
