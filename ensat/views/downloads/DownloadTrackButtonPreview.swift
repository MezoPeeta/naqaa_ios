import SwiftData
import SwiftUI

#if DEBUG
struct DownloadTrackButtonPreview: View {
    @Environment(\.modelContext) private var context
    @Environment(DownloadManager.self) private var manager
    @Query private var downloads: [DownloadedTrack]

    private let surah = Surah(
        id: 1, name: "الفاتحة", revelationPlace: .meccan, totalVerses: 7, transliteration: "Al-Fatihah"
    )
    private let item = ReciterMoshafItem.make(
        reciterId: 1, reciterName: "Preview Reciter", moshafId: 1, moshafName: "Murattal", server: "https://example.com"
    )
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 24) {
            DownloadTrackButton(surah: surah, item: item)
            Button(isRunning ? "Running…" : "Play download animation") { Task { await run() } }
                .disabled(isRunning)
        }
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        downloads.forEach(context.delete)
        manager.simulate(nil, surahId: surah.id, item: item)
        try? await Task.sleep(for: .milliseconds(600))
        for step in 0...20 {
            withAnimation { manager.simulate(.downloading(Double(step) / 20), surahId: surah.id, item: item) }
            try? await Task.sleep(for: .milliseconds(120))
        }
        withAnimation {
            context.insert(DownloadedTrack(surahId: surah.id, item: item, byteCount: 1_000_000))
            manager.simulate(nil, surahId: surah.id, item: item)
        }
        try? await Task.sleep(for: .seconds(1.5))
        manager.simulate(.failed, surahId: surah.id, item: item)
    }
}

#Preview("Download animation") {
    DownloadTrackButtonPreview()
        .modelContainer(for: DownloadedTrack.self, inMemory: true)
        .environment(DownloadManager.preview)
        .preferredColorScheme(.dark)
}
#endif
