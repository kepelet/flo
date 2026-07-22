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
          onAuthExtracted: { userAuth, webView in
            handleAuthentication(userAuth: userAuth, webView: webView)
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
  
  private func handleAuthentication(userAuth: UserAuth, webView: WKWebView) {
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
      for cookie in cookies {
        HTTPCookieStorage.shared.setCookie(cookie)
      }

      self.completeOAuthLogin(userAuth: userAuth)
    }
  }

  private func completeOAuthLogin(userAuth: UserAuth) {
    AuthService.shared.setAuthMode(AuthMode.iap)

    verifySubsonicAccess(userAuth) { success, errorMessage in
      DispatchQueue.main.async {
        if success {
          self.authViewModel.persistAuthData(userAuth)
          self.authViewModel.authMode = .iap
          self.authViewModel.isLoggedIn = true
          self.authViewModel.user = userAuth

          self.dismiss()
          self.onSuccess()
        } else {
          self.handleError(errorMessage)
        }
      }
    }
  }

  private func verifySubsonicAccess(
    _ userAuth: UserAuth, completion: @escaping (Bool, String) -> Void
  ) {
    guard var components = URLComponents(string: "\(serverURL)/rest/ping") else {
      completion(false, "Invalid server URL")
      return
    }

    components.queryItems = [
      URLQueryItem(name: "u", value: userAuth.username),
      URLQueryItem(name: "t", value: userAuth.subsonicToken),
      URLQueryItem(name: "s", value: userAuth.subsonicSalt),
      URLQueryItem(name: "v", value: AppMeta.subsonicApiVersion),
      URLQueryItem(name: "c", value: AppMeta.name),
      URLQueryItem(name: "f", value: "json"),
    ]

    guard let url = components.url else {
      completion(false, "Invalid server URL")
      return
    }

    URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
      guard let httpResponse = response as? HTTPURLResponse else {
        completion(false, "Could not verify authentication. Please check your network connection.")
        return
      }

      guard let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let subsonicResponse = json["subsonic-response"] as? [String: Any],
        let status = subsonicResponse["status"] as? String
      else {
        completion(
          false,
          "The server did not accept the session (HTTP \(httpResponse.statusCode)). Make sure Navidrome trusts your proxy (ExtAuth.TrustedSources / ReverseProxyWhitelist)."
        )
        return
      }

      if status == "ok" {
        completion(true, "")
      } else {
        let subsonicError = subsonicResponse["error"] as? [String: Any]
        let message = subsonicError?["message"] as? String ?? "Something went wrong with IAP Authentication."
        completion(false, message)
      }
    }.resume()
  }
  
  private func handleError(_ error: String) {
    localError = error
    onError(error)
  }
}
