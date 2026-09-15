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
    AuthService.shared.verifySubsonicAccess(userAuth, serverUrl: serverURL) { result in
      switch result {
      case .valid:
        completion(true, "")
      case .invalid(let message):
        completion(false, message)
      case .unreachable:
        completion(false, "Could not verify authentication. Please check your network connection.")
      }
    }
  }

  private func handleError(_ error: String) {
    localError = error
    onError(error)
  }
}
