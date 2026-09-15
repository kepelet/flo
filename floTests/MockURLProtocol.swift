//
//  MockURLProtocol.swift
//  floTests
//

import Foundation

/// A URLProtocol stub that intercepts network requests and returns canned
/// HTTP responses. Register it via `APIManager.extraProtocolClasses`.
final class MockURLProtocol: URLProtocol {

  struct Response {
    let statusCode: Int
    let data: Data
    let contentType: String

    init(statusCode: Int = 200, json: String, contentType: String = "application/json") {
      self.statusCode = statusCode
      self.data = Data(json.utf8)
      self.contentType = contentType
    }
  }

  typealias Handler = (URLRequest) -> Response?

  private static var handlers: [String: Handler] = [:]
  private static var defaultHandler: Handler?

  static func reset() {
    handlers.removeAll()
    defaultHandler = nil
  }

  static func stub(_ method: String, _ path: String, handler: @escaping Handler) {
    handlers["\(method.uppercased()) \(path)"] = handler
  }

  static func stubJSON(_ method: String, _ path: String, statusCode: Int = 200, json: String) {
    stub(method, path) { _ in
      Response(statusCode: statusCode, json: json)
    }
  }

  static func setDefaultHandler(_ handler: @escaping Handler) {
    defaultHandler = handler
  }

  // MARK: - URLProtocol

  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    let key = "\(request.httpMethod ?? "GET") \(url.path)"
    guard let response = (MockURLProtocol.handlers[key] ?? MockURLProtocol.defaultHandler)?(request)
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }

    let httpResponse = HTTPURLResponse(
      url: url,
      statusCode: response.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": response.contentType]
    )!

    client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: response.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
