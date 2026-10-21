//
//  PlayerView.swift
//  ensat
//
//  Created by Mazen on 30/08/2026.
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    let playerState: PlayerState

    @ScaledMetric private var playButtonSize: CGFloat = 72
    @Namespace private var actionsGlass

    var body: some View {
        ContainerShapeView { _ in
            stackedLayout
        } wide: { _ in
            sideBySideLayout
        }
        .background(alignment: .top) {
            GeometryReader { proxy in
                PlayerTopPattern(
                    height: topPatternHeight(for: proxy.size),
                    color: .pattern.opacity(0.35),
                    shape: .fourPointStar
                )
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
            }
        }
    }

    private var stackedLayout: some View {
        VStack(spacing: 24) {
            Spacer()

            surahTitle
            Spacer()

            metadataAndControls
        }

        .padding()
        .frame(maxHeight: .infinity)
        .safeAreaPadding(.bottom)
    }

    private var sideBySideLayout: some View {
        HStack(spacing: 24) {
            surahTitle
            .frame(maxWidth: .infinity)
            metadataAndControls
                .frame(maxWidth: .infinity)
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity)
        .safeAreaPadding(.horizontal)
    }

    private var shareMessage: String {
        let surah = playerState.selectedSurah?.displayName ?? ""
        let reciter = playerState.selectedReciter.reciter.name
        let link = "https://ensat.app/share/\(UUID().uuidString)"
        return String(localized: "Listening to \(surah) by \(reciter)") + "\n" + link
    }

    private var surahTitle: some View {
        PlayerTitleSweep(playerState: playerState)
    }

    private var metadataAndControls: some View {
        VStack {
            HStack {
                titleAndReciter
                Spacer()

                GlassEffectContainer {
                    HStack(spacing: 12) {
                        if let surah = playerState.selectedSurah {
                            FavoriteTrackButton(surahId: surah.id, item: playerState.selectedReciter)
                                .padding(4)

                                .glassEffect()
                                .glassEffectUnion(id: "trackActions", namespace: actionsGlass)
                        }
                        ShareButton(message: shareMessage)
                            .padding(4)

                            .glassEffect()
                            .glassEffectUnion(id: "trackActions", namespace: actionsGlass)
                    }
                }
            }
            .padding()

            PlayerProgressSection(playerState: playerState)

            transportControls
                .disabled(playerState.isEmpty)

            secondaryControls
        }
    }

    private var secondaryControls: some View {
        HStack(spacing: 0) {
            Spacer()
            if let surah = playerState.selectedSurah {
                DownloadTrackButton(surah: surah, item: playerState.selectedReciter)
            }
            Spacer()
            AudioRoutePickerButton()

            Spacer()

            // Placeholder: lyrics aren't implemented yet.
            Button {} label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Lyrics")
            Spacer()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .padding(.top, 40)
    }

    private var titleAndReciter: some View {
        VStack(alignment: .leading) {
            Text(playerState.selectedSurah?.displayName ?? "")
                .font(.title3)
                .bold()
                .fontWidth(.expanded)
                .contentTransition(.numericText(value: Double(playerState.selectedSurah?.id ?? 0)))
                .animation(.smooth, value: playerState.selectedSurah?.id)

            Text(playerState.selectedReciter.reciter.name)
                .foregroundStyle(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 32) {
            Button {
                playerState.playPrevious(source: "full_player")
            } label: {
                DirectionalImage("backward.fill")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous Surah")

            Button {
                playerState.togglePlayPause(source: "full_player")
            } label: {
                ZStack {
                    DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .contentTransition(
                            .symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating)
                        )
                        .opacity(playerState.isBuffering ? 0.3 : 1)

                    if playerState.isBuffering {
                        ProgressView()
                    }
                }
                .frame(width: playButtonSize, height: playButtonSize)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                playerState.isBuffering
                ? "Buffering"
                : (playerState.isPlaying ? "Pause" : "Play")
            )

            Button {
                playerState.playNext(source: "full_player")
            } label: {
                DirectionalImage("forward.fill")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next Surah")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
    }

    private func topPatternHeight(for size: CGSize) -> CGFloat {
        let proportional = size.height * 0.35
        return min(max(proportional, 100), 300)
    }
}

#if DEBUG
#Preview {
    PlayerView(playerState: .preview())
        // swiftlint:disable:next force_try
        .modelContainer(try! .preview)
        .environment(DownloadManager.preview)
        .preferredColorScheme(.dark)
        .background(.homeBackground)
}
#endif
