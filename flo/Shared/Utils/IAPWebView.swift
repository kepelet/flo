//
//  IAPWebView.swift
//  flo
//
//  Created by piekay on 08/03/26.
//

import SwiftUI
import WebKit

struct IAPWebView: UIViewRepresentable {
  let url: String
  let customHeaderName: String?
  let customCookieName: String?
  let customUsernameCookie: String?
  let onDataExtracted: (String, String, WKWebView) -> Void
  let onError: (String) -> Void
  
  func makeCoordinator() -> Coordinator {
    Coordinator(
      customHeaderName: customHeaderName,
      customCookieName: customCookieName,
      customUsernameCookie: customUsernameCookie,
      onDataExtracted: onDataExtracted,
      onError: onError
    )
  }
  
  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    context.coordinator.webView = webView
    context.coordinator.originalServerURL = url
    
    if let url = URL(string: url) {
      let request = URLRequest(url: url)
      webView.load(request)
    } else {
      onError("Invalid server URL")
    }
    
    return webView
  }
  
  func updateUIView(_ uiView: WKWebView, context: Context) {}
  
  class Coordinator: NSObject, WKNavigationDelegate {
    let customHeaderName: String?
    let customCookieName: String?
    let customUsernameCookie: String?
    let onDataExtracted: (String, String, WKWebView) -> Void
    let onError: (String) -> Void
    private var hasExtractedData = false
    private var requestCount = 0
    private let maxRequests = 10
    weak var webView: WKWebView?
    var originalServerURL: String = ""
    
    init(
      customHeaderName: String?,
      customCookieName: String?,
      customUsernameCookie: String?,
      onDataExtracted: @escaping (String, String, WKWebView) -> Void,
      onError: @escaping (String) -> Void
    ) {
      self.customHeaderName = customHeaderName
      self.customCookieName = customCookieName
      self.customUsernameCookie = customUsernameCookie
      self.onDataExtracted = onDataExtracted
      self.onError = onError
    }
    
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
      requestCount += 1
      
      if !hasExtractedData,
         let httpResponse = navigationResponse.response as? HTTPURLResponse {
        
        if httpResponse.statusCode >= 400 {
          decisionHandler(.allow)
          return
        }
        
        let headers = httpResponse.allHeaderFields
        
        var possibleTokenHeaders = [
          "x-auth-request-access-token",
          "x-auth-token",
          "x-forwarded-access-token",
          "authorization"
        ]
        
        if let customHeader = customHeaderName, !customHeader.isEmpty {
          possibleTokenHeaders.insert(customHeader.lowercased(), at: 0)
        }
        
        var extractedToken: String?
        
        for (key, value) in headers {
          if let headerName = key as? String {
            let normalizedHeader = headerName.lowercased()
            
            if possibleTokenHeaders.contains(normalizedHeader), let token = value as? String {
              extractedToken = token.replacingOccurrences(of: "Bearer ", with: "")
              break
            }
          }
        }
        
        if let token = extractedToken {
          if let responseURL = httpResponse.url?.absoluteString {
            let normalizedResponse = self.normalizeURL(responseURL)
            let normalizedOriginal = self.normalizeURL(self.originalServerURL)
            
            if normalizedResponse.hasPrefix(normalizedOriginal) {
              hasExtractedData = true
              DispatchQueue.main.async {
                if let webView = self.webView {
                  self.extractUsernameFromCookies(token: token, webView: webView)
                }
              }
              decisionHandler(.cancel)
              return
            }
          }
        }
      }
      
      if requestCount > maxRequests && !hasExtractedData {
        DispatchQueue.main.async {
          self.onError("Could not find authentication token after multiple redirects. Make sure your server uses OAuth2-Proxy or IAP.")
        }
        decisionHandler(.cancel)
        return
      }
      
      decisionHandler(.allow)
    }
    
    private func extractUsernameFromCookies(token: String, webView: WKWebView) {
      webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
        guard let self = self else { return }
        
        var username = "OAuth User"
        
        let usernameCookieName = self.customUsernameCookie ?? "username"
        
        for cookie in cookies where cookie.name == usernameCookieName {
          username = cookie.value
          break
        }
        
        DispatchQueue.main.async {
          self.onDataExtracted(token, username, webView)
        }
      }
    }
    
    private func normalizeURL(_ urlString: String) -> String {
      guard let url = URL(string: urlString) else { return urlString }
      
      var components = URLComponents()
      components.scheme = url.scheme
      components.host = url.host
      components.port = url.port
      components.path = url.path
      
      var normalized = components.string ?? urlString
      if normalized.hasSuffix("/") {
        normalized = String(normalized.dropLast())
      }
      
      return normalized.lowercased()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let currentURL = webView.url?.absoluteString else { return }
      let normalizedCurrent = normalizeURL(currentURL)
      let normalizedOriginal = normalizeURL(originalServerURL)
      
      if !hasExtractedData && normalizedCurrent.hasPrefix(normalizedOriginal) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
          var extractedToken: String?
          
          if let customCookie = self.customCookieName, !customCookie.isEmpty {
            for cookie in cookies where cookie.name == customCookie {
              extractedToken = cookie.value
              break
            }
          }
          
          if extractedToken == nil {
            for cookie in cookies where cookie.name == "KEYCLOAK_IDENTITY" {
              extractedToken = cookie.value
              break
            }
          }
          
          if extractedToken == nil {
            for cookie in cookies where cookie.name.hasPrefix("_oauth2_proxy") {
              extractedToken = cookie.value
              break
            }
          }
          
          if let token = extractedToken, !token.isEmpty, let webView = self.webView {
            var username = "OAuth User"
            
            let usernameCookieName = self.customUsernameCookie ?? "username"
            
            for cookie in cookies where cookie.name == usernameCookieName {
              username = cookie.value
              break
            }
            
            self.hasExtractedData = true
            DispatchQueue.main.async {
              self.onDataExtracted(token, username, webView)
            }
          }
        }
      }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      if !hasExtractedData {
        DispatchQueue.main.async {
          self.onError("Failed to load server: \(error.localizedDescription)")
        }
      }
    }
    
    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      if !hasExtractedData {
        DispatchQueue.main.async {
          self.onError("Failed to connect: \(error.localizedDescription)")
        }
      }
    }
  }
}
