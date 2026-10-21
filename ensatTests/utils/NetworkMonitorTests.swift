import Testing
@testable import ensat

@MainActor
@Suite(.tags(.offline))
struct NetworkMonitorTests {
    private static let delay = Duration.milliseconds(150)

    private let source = StubConnectivitySource()
    private let monitor: NetworkMonitor

    init() {
        monitor = NetworkMonitor(source: source, offlineDelay: Self.delay)
    }

    /// Lets queued main-actor hops run without waiting out the offline delay.
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(30))
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test(.tags(.timing)) func aLostConnectionOnlyCountsAfterTheDelay() async {
        source.send(connected: false)
        await settle()
        #expect(monitor.isOffline == false, "a brief drop must not make the UI jump")

        #expect(await waitUntil { monitor.isOffline })
    }

    @Test(.tags(.edgeCase))
    func aDropThatRecoversBeforeTheDelayNeverGoesOffline() async {
        source.send(connected: false)
        await settle()
        source.send(connected: true)

        try? await Task.sleep(for: Self.delay * 3)

        #expect(monitor.isOffline == false)
    }

    @Test func reconnectingGoesBackOnlineImmediately() async {
        source.send(connected: false)
        #expect(await waitUntil { monitor.isOffline })

        source.send(connected: true)

        #expect(await waitUntil { monitor.isOffline == false })
    }

    @Test(.tags(.edgeCase))
    func repeatedDisconnectsStillEndUpOffline() async {
        for _ in 0..<3 {
            source.send(connected: false)
            await settle()
        }
        #expect(await waitUntil { monitor.isOffline })
    }

    @Test func releasingTheMonitorStopsTheSource() async {
        let source = StubConnectivitySource()
        var monitor: NetworkMonitor? = NetworkMonitor(source: source, offlineDelay: Self.delay)
        #expect(monitor != nil)

        monitor = nil

        #expect(await waitUntil { source.didCancel })
    }
}
