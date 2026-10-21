import Network
import Observation

/// Reports connectivity changes. `NWPathMonitor` in the app; a stub in tests.
nonisolated protocol ConnectivitySource: AnyObject, Sendable {
    /// Called with `true` when the network is reachable, on any thread.
    var onChange: (@Sendable (Bool) -> Void)? { get set }
    func start()
    func cancel()
}

nonisolated final class NWPathConnectivitySource: ConnectivitySource, @unchecked Sendable {
    var onChange: (@Sendable (Bool) -> Void)?
    private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onChange?(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "ensat.network-monitor"))
    }

    func cancel() {
        monitor.cancel()
    }
}

/// Tracks connectivity. `isOffline` flips only after the connection has been gone for a moment,
/// so a brief drop doesn't make the UI jump.
@Observable
@MainActor
final class NetworkMonitor {
    private(set) var isOffline = false

    private let offlineDelay: Duration
    private let source: any ConnectivitySource
    private var pendingOffline: Task<Void, Never>?

    init(
        source: any ConnectivitySource = NWPathConnectivitySource(),
        offlineDelay: Duration = .milliseconds(1500)
    ) {
        self.source = source
        self.offlineDelay = offlineDelay
        source.onChange = { [weak self] isConnected in
            Task { @MainActor [weak self] in self?.update(isConnected: isConnected) }
        }
        source.start()
    }

    isolated deinit {
        source.cancel()
    }

    private func update(isConnected: Bool) {
        pendingOffline?.cancel()
        pendingOffline = nil
        if isConnected {
            isOffline = false
            return
        }
        pendingOffline = Task { [weak self, offlineDelay] in
            try? await Task.sleep(for: offlineDelay)
            guard !Task.isCancelled else { return }
            self?.isOffline = true
        }
    }
}
