import PostHog
import SwiftData
import SwiftUI

/// Download control for one surah by one reciter: idle, progress ring, downloaded, or failed.
/// The caller supplies `isDownloaded`, so lists can share one query instead of one per row.
struct DownloadControl: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pendingSize: Int64?
    @State private var showsSizeConfirmation = false
    @State private var showsRemoveConfirmation = false
    @State private var showsStorageAlert = false
    /// Set on tap so the ring morphs immediately, while the size check is still in flight.
    @State private var isPreparing = false
    @State private var prepareTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 24

    let surah: Surah
    let item: ReciterMoshafItem
    let isDownloaded: Bool
    /// Quieter idle icon for dense lists.
    var isSubtle = false

    private var state: DownloadManager.State? { manager.state(surahId: surah.id, item: item) }

    var body: some View {
        Button(action: tap) {
            icon
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PrefetchOnPressStyle(onPress: prefetchSize))
        .sensoryFeedback(.selection, trigger: isDownloaded)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .onDisappear { prepareTask?.cancel() }
        .confirmationDialog(
            Text("Download \(surah.displayName)?"),
            isPresented: $showsSizeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Download") { start(expectedBytes: pendingSize) }
        } message: {
            if let pendingSize {
                Text("This file is \(pendingSize.formatted(.byteCount(style: .file))).")
            }
        }
        .alert("Not enough storage", isPresented: $showsStorageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free up space on your device to download this surah.")
        }
        .confirmationDialog(
            Text("Remove download?"),
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Download", role: .destructive) {
                PostHogSDK.shared.capture("surah_download_removed", properties: analyticsProperties)
                manager.remove(surahId: surah.id, item: item)
            }
        }
    }

    private enum Phase: Equatable { case idle, downloading, failed, downloaded }

    private var phase: Phase {
        if isDownloaded { return .downloaded }
        switch state {
        case .downloading: return .downloading
        case .failed: return .failed
        case nil: return isPreparing ? .downloading : .idle
        }
    }

    private var progress: Double {
        if case .downloading(let fraction) = state { return max(fraction, 0.02) }
        return 0
    }

    /// One ring for every state, so tapping morphs the same shapes instead of swapping views.
    private var icon: some View {
        let idleColor: Color = isSubtle ? .secondary : .primary
        return ZStack {
            Circle()
                .fill(isSubtle ? Color.secondary : Color.selectedText)
                .opacity(phase == .downloaded ? 1 : 0)
            Circle()
                .stroke(
                    phase == .failed ? Color.red : phase == .downloading ? Color.secondary.opacity(0.3) : idleColor,
                    lineWidth: phase == .downloading ? 3 : 2
                )
                .opacity(phase == .downloaded ? 0 : 1)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.selectedText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
            Image(systemName: glyph)
                .font(.system(size: ringSize * (phase == .downloading ? 0.4 : 0.5), weight: .semibold))
                .foregroundStyle(glyphColor(idle: idleColor))
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: iconSize, height: iconSize)
        .scaleEffect(phase == .downloading && !reduceMotion ? 0.92 : 1)
        .animation(.smooth(duration: 0.4), value: phase)
    }

    private var iconSize: CGFloat { ringSize * (isSubtle ? 0.9 : 1) }

    private var accessibilityValue: Text {
        if let state { return Self.percent(for: state) }
        return isPreparing ? Text("Checking file size") : Text(verbatim: "")
    }

    /// Begins the size check on touch-down, so most of its latency is gone by the time the tap lands.
    private func prefetchSize() {
        guard !isDownloaded, state == nil, !isPreparing else { return }
        manager.prefetchFileSize(surah: surah, item: item)
    }

    private static func percent(for state: DownloadManager.State) -> Text {
        if case .downloading(let fraction) = state { return Text(fraction, format: .percent.precision(.fractionLength(0))) }
        return Text(verbatim: "")
    }

    private var glyph: String {
        switch phase {
        case .idle: "arrow.down"
        case .downloading: "stop.fill"
        case .failed: "arrow.clockwise"
        case .downloaded: "checkmark"
        }
    }

    private func glyphColor(idle: Color) -> Color {
        switch phase {
        case .idle: idle
        case .downloading: .primary
        case .failed: .red
        case .downloaded: .black
        }
    }

    private var accessibilityLabel: LocalizedStringKey {
        if isDownloaded { return "Downloaded. Tap to remove" }
        switch state {
        case .downloading: return "Downloading. Tap to cancel"
        case .failed: return "Download failed. Tap to retry"
        case nil: return "Download"
        }
    }

    private func tap() {
        if isDownloaded {
            showsRemoveConfirmation = true
            return
        }
        if case .downloading = state {
            manager.cancel(surahId: surah.id, item: item)
            return
        }
        // A second tap while the size check is running cancels it.
        if isPreparing {
            prepareTask?.cancel()
            prepareTask = nil
            isPreparing = false
            return
        }
        isPreparing = true
        prepareTask = Task {
            let size = await manager.fileSize(surah: surah, item: item)
            guard !Task.isCancelled else { return }
            if let size, size > DownloadManager.confirmationThreshold {
                isPreparing = false
                pendingSize = size
                showsSizeConfirmation = true
            } else {
                start(expectedBytes: size)
            }
        }
    }

    private func start(expectedBytes: Int64?) {
        defer { isPreparing = false }
        switch manager.download(surah: surah, item: item, expectedBytes: expectedBytes) {
        case .started:
            PostHogSDK.shared.capture("surah_download_started", properties: analyticsProperties)
        case .insufficientSpace:
            showsStorageAlert = true
        case .alreadyRunning, .unavailable:
            break
        }
    }

    private var analyticsProperties: [String: Any] {
        [
            "surah_id": surah.id,
            "reciter_id": item.reciter.id,
            "moshaf_id": item.moshaf.id
        ]
    }
}
