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
  let onAuthExtracted: (UserAuth, WKWebView) -> Void
  let onError: (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onAuthExtracted: onAuthExtracted, onError: onError)
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
      context.coordinator.startTimeout()
    } else {
      onError("Invalid server URL")
    }

    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}

  class Coordinator: NSObject, WKNavigationDelegate {
    let onAuthExtracted: (UserAuth, WKWebView) -> Void
    let onError: (String) -> Void
    private var hasExtractedData = false
    private var timeoutWorkItem: DispatchWorkItem?
    weak var webView: WKWebView?
    var originalServerURL: String = ""

    private static let timeoutInterval: TimeInterval = 90

    private static let appConfigScript = """
      (function() {
        var c = window.__APP_CONFIG__;
        if (!c) { return null; }
        return (typeof c === 'string') ? c : JSON.stringify(c);
      })()
      """

    init(
      onAuthExtracted: @escaping (UserAuth, WKWebView) -> Void,
      onError: @escaping (String) -> Void
    ) {
      self.onAuthExtracted = onAuthExtracted
      self.onError = onError
    }

    func startTimeout() {
      let workItem = DispatchWorkItem { [weak self] in
        guard let self, !self.hasExtractedData else { return }
        self.cancelTimeout()
        DispatchQueue.main.async {
          self.onError(
            "Timed out waiting for the server to authenticate. Make sure Navidrome is behind Authentik/Caddy and reachable."
          )
        }
      }
      timeoutWorkItem = workItem
      DispatchQueue.main.asyncAfter(
        deadline: .now() + Self.timeoutInterval, execute: workItem
      )
    }

    private func cancelTimeout() {
      timeoutWorkItem?.cancel()
      timeoutWorkItem = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard !hasExtractedData, let currentURL = webView.url?.absoluteString else { return }

      let normalizedCurrent = normalizeURL(currentURL)
      let normalizedOriginal = normalizeURL(originalServerURL)

      guard normalizedCurrent.hasPrefix(normalizedOriginal) else { return }

      webView.evaluateJavaScript(Self.appConfigScript) { [weak self] result, _ in
        guard let self = self, !self.hasExtractedData else { return }

        guard let jsonString = result as? String,
          let jsonData = jsonString.data(using: .utf8),
          let appConfig = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let authPayload = appConfig["auth"] as? [String: Any],
          let authData = try? JSONSerialization.data(withJSONObject: authPayload),
          let userAuth = try? JSONDecoder().decode(UserAuth.self, from: authData)
        else {
          self.hasExtractedData = true
          self.cancelTimeout()
          DispatchQueue.main.async {
            self.onError(
              "Could not read authentication data from the server. Make sure Navidrome is behind Authentik/Caddy and serving the expected login page."
            )
          }
          return
        }

        self.hasExtractedData = true
        self.cancelTimeout()
        DispatchQueue.main.async {
          self.onAuthExtracted(userAuth, webView)
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

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      if !hasExtractedData {
        cancelTimeout()
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
        cancelTimeout()
        DispatchQueue.main.async {
          self.onError("Failed to connect: \(error.localizedDescription)")
        }
      }
    }
  }
}
