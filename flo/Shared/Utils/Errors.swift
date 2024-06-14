//
//  Errors.swift
//  flo
//
//  Created by rizaldy on 09/06/24.
//

import Alamofire
import Foundation

enum AuthResult<T> {
  case success(T)
  case failure(AuthError)

  init(result: Result<T, Error>) {
    switch result {
    case .success(let value):
      self = .success(value)
    case .failure(let error):
      if let authError = error as? AuthError {
        self = .failure(authError)
      } else {
        self = .failure(.unknown)
      }
    }
  }
}

enum AuthError: Error {
  case server(message: String)
  case unknown
}

struct ErrorResponse: Decodable {
  let error: String
}

class ErrorHandler {
  static func mapError(_ error: AFError) -> Error {
    if let underlyingError = error.underlyingError as? URLError {
      return AuthError.server(message: underlyingError.localizedDescription)
    }
    return AuthError.unknown
  }

  static func handleFailure<T>(
    _ afError: AFError, response: DataResponse<T, AFError>,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
    if let data = response.data {
      do {
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
        let errorMessage = errorResponse.error
        completion(.failure(AuthError.server(message: errorMessage)))
      } catch {
        completion(.failure(mapError(afError)))
      }
    } else {
      completion(.failure(mapError(afError)))
    }
  }
}
