import Foundation
@testable import ensat

/// Lets a test push connectivity changes into `NetworkMonitor`.
final class StubConnectivitySource: ConnectivitySource, @unchecked Sendable {
    var onChange: (@Sendable (Bool) -> Void)?
    private let lock = NSLock()
    private var started = false
    private var cancelled = false

    var didStart: Bool { lock.withLock { started } }
    var didCancel: Bool { lock.withLock { cancelled } }

    func start() { lock.withLock { started = true } }
    func cancel() { lock.withLock { cancelled = true } }

    func send(connected: Bool) { onChange?(connected) }
}
