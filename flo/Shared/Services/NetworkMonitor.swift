import Foundation
import Network
import UIKit

final class NetworkMonitor: ObservableObject {
  static let shared = NetworkMonitor()

  @Published private(set) var isOnline = true
  @Published private(set) var isServerReachable = true

  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "net.faultables.flo.networkmonitor")
  private var serverProbe: NWConnection?

  /// Bumped every time a probe starts, times out, or the device goes offline.
  /// Probe callbacks capture the generation they belong to and ignore stale
  /// results, so an orphaned timeout (or a late `.ready`) can never overwrite
  /// the outcome of a newer probe.
  private var probeGeneration = 0

  private var probeTimer: Timer?
  private let probeTimeout: TimeInterval = 3
  private let probeInterval: TimeInterval = 30

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }

        let wasOnline = self.isOnline
        self.isOnline = path.status == .satisfied

        if !wasOnline && self.isOnline {
          self.probeServerReachability()
          NotificationCenter.default.post(name: .networkBecameOnline, object: nil)
        } else if wasOnline && !self.isOnline {
          // Device went offline: an in-flight probe result is meaningless,
          // and nothing outside this app can reach the server either.
          self.probeGeneration += 1
          self.serverProbe?.cancel()
          self.isServerReachable = false
        }
      }
    }

    monitor.start(queue: monitorQueue)

    NotificationCenter.default.addObserver(
      self, selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)

    probeServerReachability()
    startPeriodicProbe()
  }

  deinit {
    monitor.cancel()
    probeTimer?.invalidate()
    serverProbe?.cancel()
  }

  @objc private func handleAppDidBecomeActive() {
    probeServerReachability()
  }

  private func startPeriodicProbe() {
    probeTimer = Timer.scheduledTimer(withTimeInterval: probeInterval, repeats: true) {
      [weak self] _ in
      self?.probeServerReachability()
    }
  }

  private func serverEndpoint() -> (host: String, port: UInt16)? {
    guard
      let url = URL(string: UserDefaultsManager.serverBaseURL),
      let host = url.host, !host.isEmpty
    else {
      return nil
    }

    let scheme = url.scheme?.lowercased() ?? ""
    let port = UInt16(url.port ?? (scheme == "https" ? 443 : 80))
    return (host, port)
  }

  /// Probes TCP reachability of the configured server host.
  ///
  /// When `completion` is provided it is invoked on the main queue exactly
  /// once with the final verdict — unless a newer probe superseded this one,
  /// in which case the newer probe owns the result.
  func probeServerReachability(completion: ((Bool) -> Void)? = nil) {
    let generation = probeGeneration + 1
    probeGeneration = generation

    serverProbe?.cancel()

    guard isOnline else {
      isServerReachable = false
      completion?(false)
      return
    }

    guard let endpoint = serverEndpoint() else {
      // No server configured yet: leave the previous verdict untouched.
      completion?(isServerReachable)
      return
    }

    let connection = NWConnection(
      host: NWEndpoint.Host(endpoint.host),
      port: NWEndpoint.Port(rawValue: endpoint.port) ?? .https,
      using: .tcp
    )
    serverProbe = connection

    connection.stateUpdateHandler = { [weak self] state in
      DispatchQueue.main.async {
        guard let self = self, self.probeGeneration == generation else { return }

        switch state {
        case .ready:
          self.isServerReachable = true
          connection.cancel()
          completion?(true)
        case .failed:
          self.isServerReachable = false
          completion?(false)
        default:
          break
        }
      }
    }

    connection.start(queue: monitorQueue)

    DispatchQueue.main.asyncAfter(deadline: .now() + probeTimeout) { [weak self] in
      guard let self = self, self.probeGeneration == generation else { return }

      // Invalidate this probe so a late `.ready`/`.failed` from it can't
      // override the timeout verdict; the periodic/app-active probes will
      // re-check.
      self.probeGeneration += 1
      self.isServerReachable = false
      connection.cancel()
      completion?(false)
    }
  }
}

extension Notification.Name {
  static let networkBecameOnline = Notification.Name("net.faultables.flo.networkBecameOnline")
}