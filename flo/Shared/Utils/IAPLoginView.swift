//
//  IAPLoginView.swift
//  flo
//
//  Created by piekay on 08/03/26.
//

import SwiftUI
import WebKit

struct IAPLoginView: View {
  @ObservedObject var authViewModel: AuthViewModel
  @Environment(\.dismiss) private var dismiss
  
  @State private var serverUrl: String = ""
  @State private var showWebAuth = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  var body: some View {
    NavigationView {
      oauthLoginView
    }
  }
    
  private var oauthLoginView: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(systemName: "lock.shield.fill")
          .font(.system(size: 60))
          .foregroundStyle(.blue)
        
        Text("IAP Authentication")
          .font(.title)
          .fontWeight(.bold)
        
        Text("Authenticate using Identity-Aware Proxy")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 40)
      
      HStack(spacing: 12) {
        Image(systemName: "info.circle.fill")
          .foregroundStyle(.blue)
        
        Text("Your server URL will be opened to authenticate. The IAP token will be extracted automatically.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding()
      .background(Color.blue.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal)
      
      VStack(alignment: .leading, spacing: 8) {
        Text("Server URL")
          .font(.headline)
        
        TextField("https://your-iap-server.com", text: $serverUrl)
          .textFieldStyle(.roundedBorder)
          .autocapitalization(.none)
          .keyboardType(.URL)
          .autocorrectionDisabled()
          .disabled(isLoading)
      }
      .padding(.horizontal)
      
      Button(action: {
        authenticateWithIAP()
      }) {
        HStack {
          if isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white)
          }
          
          Text(isLoading ? "Authenticating..." : "Authenticate with IAP")
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(canSubmit ? Color.blue : Color.gray)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .disabled(!canSubmit || isLoading)
      .padding(.horizontal)
      
      if let error = errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }
    }
    .navigationTitle("IAP Login")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
    }
    .sheet(isPresented: $showWebAuth) {
      IAPWebAuthView(
        serverURL: serverUrl,
        authViewModel: authViewModel,
        onSuccess: {
          dismiss()
        },
        onError: { error in
          errorMessage = error
          isLoading = false
        }
      )
    }
  }
  
  private var canSubmit: Bool {
    !serverUrl.isEmpty && !isLoading
  }
  
  private func authenticateWithIAP() {
    errorMessage = nil
    isLoading = true
    authViewModel.serverUrl = serverUrl
    showWebAuth = true
  }
}

private struct IAPWebAuthView: View {
  let serverURL: String
  @ObservedObject var authViewModel: AuthViewModel
  let onSuccess: () -> Void
  let onError: (String) -> Void
  
  @Environment(\.dismiss) private var dismiss
  @State private var isLoading = false
  @State private var localError: String?
  
  var body: some View {
    NavigationView {
      ZStack {
        IAPWebView(
          url: serverURL,
          onJWTExtracted: { jwt, webView in
            handleJWT(jwt, webView: webView)
          },
          onError: { error in
            handleError(error)
          }
        )
        
        if let error = localError {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 50))
              .foregroundStyle(.orange)
            
            Text("Authentication Failed")
              .font(.headline)
            
            Text(error)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
            
            Button("Try Again") {
              localError = nil
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
              dismiss()
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemBackground))
        }
      }
      .navigationTitle("Sign In")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
  
  private func handleJWT(_ jwt: String, webView: WKWebView) {
    let username = extractUsernameFromJWT(jwt) ?? "OAuth User"

      webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
      
      for cookie in cookies {
        HTTPCookieStorage.shared.setCookie(cookie)
      }
      
      self.completeOAuthLogin(jwt: jwt, username: username)
    }
  }
  
  private func completeOAuthLogin(jwt: String, username: String) {
    let iapInfo = IAPAuthInfo(jwtAssertion: jwt, userEmail: username, userId: nil)
    AuthService.shared.setIAPAuthInfo(iapInfo)
    AuthService.shared.setAuthMode(AuthMode.iap)
    
    let userAuth = UserAuth(
      id: username,
      username: username,
      name: username,
      isAdmin: false,
      lastFMApiKey: "",
      subsonicSalt: "",
      subsonicToken: "",
      token: jwt
    )
    
    let testURL = "\(serverURL)/api/ping"
    
    var request = URLRequest(url: URL(string: testURL)!)
    request.httpMethod = "GET"
    
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
          DispatchQueue.main.async {
            self.authViewModel.persistAuthData(userAuth)
            self.authViewModel.isLoggedIn = true
            self.authViewModel.user = userAuth
            
            self.dismiss()
            self.onSuccess()
          }
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
          
          DispatchQueue.main.async {
            self.handleError("Something went wrong with IAP Authentication.")
          }
        } else {
          DispatchQueue.main.async {
            self.authViewModel.persistAuthData(userAuth)
            self.authViewModel.isLoggedIn = true
            self.authViewModel.user = userAuth
            
            self.dismiss()
            self.onSuccess()
          }
        }
      } else {
        DispatchQueue.main.async {
          self.handleError("Could not verify authentication. Please check your network connection.")
        }
      }
    }.resume()
  }
  
  private func extractUsernameFromJWT(_ jwt: String) -> String? {
    let segments = jwt.components(separatedBy: ".")
    guard segments.count > 1 else { return nil }
    
    let payloadSegment = segments[1]
    
    // Add padding if needed for base64 decoding
    var base64 = payloadSegment
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    let paddingLength = (4 - base64.count % 4) % 4
    base64 += String(repeating: "=", count: paddingLength)
    
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    
    print("📋 JWT Payload: \(json)")
    
    // Try different possible username fields
    if let username = json["preferred_username"] as? String {
      return username
    } else if let username = json["email"] as? String {
      return username
    } else if let username = json["sub"] as? String {
      return username
    }
    
    return nil
  }
  
  private func handleError(_ error: String) {
    localError = error
    onError(error)
  }
}

private struct IAPWebView: UIViewRepresentable {
  let url: String
  let onJWTExtracted: (String, WKWebView) -> Void
  let onError: (String) -> Void
  
  func makeCoordinator() -> Coordinator {
    Coordinator(onJWTExtracted: onJWTExtracted, onError: onError)
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
    let onJWTExtracted: (String, WKWebView) -> Void
    let onError: (String) -> Void
    private var hasExtractedJWT = false
    private var requestCount = 0
    private let maxRequests = 10
    weak var webView: WKWebView?
    var originalServerURL: String = ""
    
    init(onJWTExtracted: @escaping (String, WKWebView) -> Void, onError: @escaping (String) -> Void) {
      self.onJWTExtracted = onJWTExtracted
      self.onError = onError
    }
    
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
      requestCount += 1
      
      if !hasExtractedJWT,
         let httpResponse = navigationResponse.response as? HTTPURLResponse {
        
        if httpResponse.statusCode >= 400 {
          decisionHandler(.allow)
          return
        }
        
        let headers = httpResponse.allHeaderFields
        
        let possibleTokenHeaders = [
          "x-goog-iap-jwt-assertion",
          "x-auth-request-access-token",
          "x-auth-token",
          "x-forwarded-access-token",
          "authorization"
        ]
        
        for (key, value) in headers {
          if let headerName = key as? String {
            let normalizedHeader = headerName.lowercased()
            
            if possibleTokenHeaders.contains(normalizedHeader) {
              if let token = value as? String {
                let cleanToken = token.replacingOccurrences(of: "Bearer ", with: "")
                
                if let responseURL = httpResponse.url?.absoluteString {
                  
                  let normalizedResponse = self.normalizeURL(responseURL)
                  let normalizedOriginal = self.normalizeURL(self.originalServerURL)
                  
                  if normalizedResponse.hasPrefix(normalizedOriginal) {
                    hasExtractedJWT = true
                    DispatchQueue.main.async {
                      if let webView = self.webView {
                        self.onJWTExtracted(cleanToken, webView)
                      }
                    }
                    decisionHandler(.cancel)
                    return
                  } else {}
                }
              }
            }
          }
        }
      }
      
      if requestCount > maxRequests && !hasExtractedJWT {
        DispatchQueue.main.async {
          self.onError("Could not find authentication token after multiple redirects. Make sure your server uses OAuth2-Proxy or IAP.")
        }
        decisionHandler(.cancel)
        return
      }
      
      decisionHandler(.allow)
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
      
      if !hasExtractedJWT && normalizedCurrent.hasPrefix(normalizedOriginal) {
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
          
          for cookie in cookies {
            if cookie.name == "KEYCLOAK_IDENTITY" {
              let jwt = cookie.value
              self.hasExtractedJWT = true
              DispatchQueue.main.async {
                if let webView = self.webView {
                  self.onJWTExtracted(jwt, webView)
                }
              }
              return
            }
          }
          
          // Fallback: look for OAuth2-Proxy session cookie
          for cookie in cookies {
            if cookie.name.hasPrefix("_oauth2_proxy") {
              self.hasExtractedJWT = true
              DispatchQueue.main.async {
                if let webView = self.webView {
                  self.onJWTExtracted(cookie.value, webView)
                }
              }
              return
            }
          }
          
          if !self.hasExtractedJWT {}
        }
      } else if !normalizedCurrent.hasPrefix(normalizedOriginal) {}
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      if !hasExtractedJWT {
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
      if !hasExtractedJWT {
        DispatchQueue.main.async {
          self.onError("Failed to connect: \(error.localizedDescription)")
        }
      }
    }
  }
}

#Preview {
  IAPLoginView(authViewModel: AuthViewModel())
}
