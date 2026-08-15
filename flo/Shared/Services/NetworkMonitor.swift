import Foundation
import Network

final class NetworkMonitor: ObservableObject {
  static let shared = NetworkMonitor()

  @Published private(set) var isOnline = true

  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "net.faultables.flo.networkmonitor")

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }

        let wasOnline = self.isOnline
        self.isOnline = path.status == .satisfied

        if !wasOnline && self.isOnline {
          NotificationCenter.default.post(name: .networkBecameOnline, object: nil)
        }
      }
    }

    monitor.start(queue: monitorQueue)
  }
}

extension Notification.Name {
  static let networkBecameOnline = Notification.Name("net.faultables.flo.networkBecameOnline")
}
