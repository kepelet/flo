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

enum AuthError: Error, Equatable {
  case server(message: String)
  case sessionExpired
  case unknown
}

struct ErrorResponse: Decodable {
  let error: String
}

class ErrorHandler {
  static func isSessionExpired(statusCode: Int?) -> Bool {
    guard let code = statusCode else { return false }
    return code == 401 || code == 403
  }

  static func isSessionExpired(error: AFError) -> Bool {
    return error.responseCode == 401 || error.responseCode == 403
  }

  static func mapError(_ error: AFError) -> Error {
    if isSessionExpired(error: error) {
      return AuthError.sessionExpired
    }
    if let underlyingError = error.underlyingError as? URLError {
      return AuthError.server(message: underlyingError.localizedDescription)
    }
    return AuthError.unknown
  }

  static func handleFailure<T>(
    _ afError: AFError, response: DataResponse<T, AFError>,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
    // Preserve server message when available; 401 from /auth/login should
    // surface as .server("invalid username or password"), not as a ghost
    // session — the caller is not yet logged in. For other endpoints the
    // 401 is surfaced via APIManager's sessionExpired notification and
    // ErrorHandler.isSessionExpired / mapError.
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
