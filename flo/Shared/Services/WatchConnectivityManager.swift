//
//  WatchConnectivityManager.swift
//  flo
//
//  Created by Codex on 17/02/26.
//

import Combine
import Foundation

#if os(iOS)
  import WatchConnectivity

  final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private override init() {
      super.init()
    }

    func start() {
      session?.delegate = self
      session?.activate()
    }

    func session(
      _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
      session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
      PlaybackCoordinator.shared.handleWatchCommand(message)
    }

    func session(
      _ session: WCSession,
      didReceiveMessage message: [String: Any],
      replyHandler: @escaping ([String: Any]) -> Void
    ) {
      if message["request"] != nil {
        WatchLibraryResponder.shared.handle(message: message, replyHandler: replyHandler)
      } else {
        PlaybackCoordinator.shared.handleWatchCommand(message)

        replyHandler(["result": "ok"])
      }
    }
  }
#endif

#if os(watchOS)
  import WatchConnectivity

  final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isActivated = false
    @Published var isServerOnline = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private override init() {
      super.init()

      session?.delegate = self
      session?.activate()

      isReachable = session?.isReachable ?? false
      isActivated = session?.activationState == .activated
    }

    func sendMessage(_ message: [String: Any]) {
      guard let session else { return }

      if session.activationState != .activated {
        if session.activationState == .notActivated {
          session.activate()
        }

        return
      }

      if session.isReachable {
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
      }
    }

    func requestLibrary(
      type: String,
      parameters: [String: Any] = [:],
      completion: @escaping (Result<Any, Error>) -> Void
    ) {
      guard let session else {
        completion(.failure(WatchConnectivityError(message: "Session unavailable.")))

        return
      }

      guard session.activationState == .activated else {
        if session.activationState == .notActivated {
          session.activate()
        }

        completion(.failure(WatchConnectivityError(message: "WCSession not activated.")))

        return
      }

      guard session.isReachable else {
        completion(.failure(WatchConnectivityError(message: "iPhone is not reachable.")))

        return
      }

      var message = parameters
      message["request"] = type

      session.sendMessage(message) { reply in
        if let result = reply["result"] as? String, result == "ok", let data = reply["data"] {
          completion(.success(data))
        } else {
          let message = reply["message"] as? String ?? "Unexpected response."

          completion(.failure(WatchConnectivityError(message: message)))
        }
      } errorHandler: { error in
        completion(.failure(error))
      }
    }

    func requestNowPlaying(completion: @escaping (Result<[String: Any], Error>) -> Void) {
      guard let session else {
        completion(.failure(WatchConnectivityError(message: "Session unavailable.")))

        return
      }

      guard session.activationState == .activated else {
        if session.activationState == .notActivated {
          session.activate()
        }

        completion(.failure(WatchConnectivityError(message: "WCSession not activated.")))

        return
      }

      guard session.isReachable else {
        completion(.failure(WatchConnectivityError(message: "iPhone is not reachable.")))

        return
      }

      session.sendMessage(["request": "nowPlaying"]) { reply in
        if let result = reply["result"] as? String, result == "ok",
          let data = reply["data"] as? [String: Any]
        {
          completion(.success(data))
        } else {
          let message = reply["message"] as? String ?? "Unexpected response."

          completion(.failure(WatchConnectivityError(message: message)))
        }
      } errorHandler: { error in
        completion(.failure(error))
      }
    }

    func requestServerStatus(completion: @escaping (Bool) -> Void) {
      guard let session else {
        completion(false)

        return
      }

      guard session.activationState == .activated else {
        if session.activationState == .notActivated {
          session.activate()
        }

        completion(false)

        return
      }

      guard session.isReachable else {
        completion(false)

        return
      }

      session.sendMessage(["request": "serverStatus"]) { reply in
        if let result = reply["result"] as? String,
          result == "ok",
          let data = reply["data"] as? [String: Any],
          let isOnline = data["isOnline"] as? Bool
        {
          completion(isOnline)
        } else {
          completion(false)
        }
      } errorHandler: { _ in
        completion(false)
      }
    }

    func refreshServerStatus() {
      requestServerStatus { [weak self] isOnline in
        DispatchQueue.main.async {
          self?.isServerOnline = isOnline
        }
      }
    }

    func ping(completion: ((Result<Void, Error>) -> Void)? = nil) {
      guard let session else {
        completion?(.failure(WatchConnectivityError(message: "Session unavailable.")))

        return
      }

      guard session.activationState == .activated else {
        if session.activationState == .notActivated {
          session.activate()
        }

        completion?(.failure(WatchConnectivityError(message: "WCSession not activated.")))

        return
      }

      guard session.isReachable else {
        completion?(.failure(WatchConnectivityError(message: "iPhone is not reachable.")))

        return
      }

      session.sendMessage(["request": "ping"]) { reply in
        if let result = reply["result"] as? String, result == "ok" {
          completion?(.success(()))
        } else {
          let message = reply["message"] as? String ?? "Unexpected response."

          completion?(.failure(WatchConnectivityError(message: message)))
        }
      } errorHandler: { error in
        completion?(.failure(error))
      }
    }

    struct WatchConnectivityError: LocalizedError {
      let message: String

      var errorDescription: String? {
        message
      }
    }

    func session(
      _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
    ) {
      DispatchQueue.main.async {
        self.isReachable = session.isReachable
        self.isActivated = activationState == .activated
      }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
      DispatchQueue.main.async {
        self.isReachable = session.isReachable
        self.isActivated = session.activationState == .activated
      }
    }
  }
#endif
