//
//  IAPWebAuthView.swift
//  flo
//
//  Created by piekay on 13/03/26.
//

import SwiftUI
import WebKit

struct IAPWebAuthView: View {
  let serverURL: String
  @ObservedObject var authViewModel: AuthViewModel
  let customHeaderName: String?
  let customCookieName: String?
  let customUsernameCookie: String?
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
          customHeaderName: customHeaderName,
          customCookieName: customCookieName,
          customUsernameCookie: customUsernameCookie,
          onDataExtracted: { jwt, username, webView in
            handleAuthentication(jwt: jwt, username: username, webView: webView)
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
  
  private func handleAuthentication(jwt: String, username: String, webView: WKWebView) {
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
  
  private func handleError(_ error: String) {
    localError = error
    onError(error)
  }
}
