import Foundation
import Network

final class NetworkMonitor: ObservableObject {
  static let shared = NetworkMonitor()

  @Published private(set) var isOnline = true
  @Published private(set) var isServerReachable = true

  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "net.faultables.flo.networkmonitor")
  private var serverProbe: NWConnection?

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }

        let wasOnline = self.isOnline
        self.isOnline = path.status == .satisfied

        if !wasOnline && self.isOnline {
          self.probeServerReachability()
          NotificationCenter.default.post(name: .networkBecameOnline, object: nil)
        }
      }
    }

    monitor.start(queue: monitorQueue)
    probeServerReachability()
  }

  func probeServerReachability() {
    serverProbe?.cancel()

    guard isOnline else {
      isServerReachable = false
      return
    }

    guard
      let url = URL(string: UserDefaultsManager.serverBaseURL),
      let host = url.host, !host.isEmpty
    else {
      return
    }

    let scheme = url.scheme?.lowercased() ?? ""
    let port =
      NWEndpoint.Port(rawValue: UInt16(url.port ?? (scheme == "https" ? 443 : 80))) ?? .https

    let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
    serverProbe = connection

    var didResolve = false

    connection.stateUpdateHandler = { [weak self] state in
      DispatchQueue.main.async {
        guard let self = self else { return }

        switch state {
        case .ready:
          didResolve = true
          self.isServerReachable = true
          connection.cancel()
        case .failed:
          self.isServerReachable = false
        default:
          break
        }
      }
    }

    connection.start(queue: monitorQueue)

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self = self, !didResolve else { return }
      self.isServerReachable = false
      connection.cancel()
    }
  }
}

extension Notification.Name {
  static let networkBecameOnline = Notification.Name("net.faultables.flo.networkBecameOnline")
}
