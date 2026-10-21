import AVFoundation
import Observation

/// Tracks the current audio output route so the UI can show the active device.
@Observable @MainActor
final class AudioRouteMonitor {
    private(set) var symbolName = "iphone"
    private(set) var deviceName = ""

    init() {
        refresh()
    }

    /// Re-reads the route every time it changes. Call from a `.task`; it ends when the task is cancelled.
    func observe() async {
        for await _ in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
            refresh()
        }
    }

    private func refresh() {
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
            symbolName = "iphone"
            deviceName = ""
            return
        }
        deviceName = output.portName
        symbolName = Self.symbol(for: output)
    }

    private static func symbol(for output: AVAudioSessionPortDescription) -> String {
        switch output.portType {
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            output.portName.localizedCaseInsensitiveContains("airpods") ? "airpods" : "hifispeaker"
        case .headphones, .headsetMic:
            "headphones"
        case .airPlay:
            "airplayaudio"
        case .builtInSpeaker, .builtInReceiver:
            "iphone"
        default:
            "speaker.wave.2"
        }
    }
}
