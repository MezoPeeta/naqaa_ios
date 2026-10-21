import SwiftUI

struct PlayerSurahTitle: View {
    let id: Int
    /// Starts the erase sweep ahead of the title change. See `AnimatedText`.
    /// Drives the erase directly, 0 (intact) to 1 (erased). Takes precedence over `isErasing`.
    var eraseProgress: Double?
    var isErasing = false
    var configuration = PlayerSurahTitle.defaultConfiguration

    private var key: String { String(format: "surah%03d", id) }
    private var font: Font { .custom("surah-name-v4", size: 170) }

    /// The scheduled erase runs slowly while the track winds down. `eraseDuration` only applies
    /// when the title changes without that, such as a manual skip.
    static let defaultConfiguration: AnimatedTextConfiguration = {
        var configuration = AnimatedTextConfiguration()
        configuration.eraseDuration = 1
        configuration.scheduledEraseDuration = 4
        configuration.revealDuration = 2
        configuration.style = .path
        configuration.eraseTint = .green

        return configuration
    }()

    /// The shadow layers follow the same sweep, with their own tint, glow and soft copy settings.
    private var shadowConfiguration: AnimatedTextConfiguration {
        var plain = configuration
        plain.tintStrength = 1
        plain.glowRadius = 2
        plain.blur = 10
        plain.drift = 0
        return plain
    }

    var body: some View {
        ZStack {
            AnimatedText(key, eraseProgress: eraseProgress, isErasing: isErasing, configuration: shadowConfiguration)
                .font(font)
                .foregroundStyle(.black)
                .offset(y: 10)
                .blur(radius: 18)
                .opacity(0.5)
            AnimatedText(key, eraseProgress: eraseProgress, isErasing: isErasing, configuration: shadowConfiguration)
                .font(font)
                .foregroundStyle(.black)
                .offset(y: 3)
                .blur(radius: 4)
                .opacity(0.6)
            // Face
            AnimatedText(key, eraseProgress: eraseProgress, isErasing: isErasing, configuration: configuration)
                .font(font)
        }
        .bold()
        .fontWidth(.expanded)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        PlayerSurahTitle(id: 1)
        PlayerSurahTitle(id: 2)
        PlayerSurahTitle(id: 114)
    }
    .padding()
}

#if DEBUG
/// Keeps swapping the surah so the erase and reveal animation repeats without tapping anything,
/// with the same configuration controls as the playground.
private struct PlayerSurahTitleLooping: View {
    @State private var id = 1
    @State private var isLooping = true
    @State private var interval = 4.0
    @State private var configuration = PlayerSurahTitle.defaultConfiguration
    private let surahIds = [1, 2, 36, 112, 114]

    var body: some View {
        VStack(spacing: 0) {
            PlayerSurahTitle(id: id, configuration: configuration)
                .frame(height: 220)
                .padding(.horizontal)

            Form {
                Section("Loop") {
                    Toggle("Loop", isOn: $isLooping)
                    HStack {
                        Text("Every")
                        Slider(value: $interval, in: 1...10, step: 0.5)
                        Text("\(interval, format: .number.precision(.fractionLength(1)))s")
                            .monospacedDigit()
                    }
                    Button("Next now") { advance() }
                }

                AnimatedTextConfigurationSections(configuration: $configuration)
            }
        }
        // Restarts whenever the loop is toggled or the interval changes.
        .task(id: LoopSettings(isLooping: isLooping, interval: interval)) {
            guard isLooping else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                advance()
            }
        }
    }

    private struct LoopSettings: Equatable {
        let isLooping: Bool
        let interval: Double
    }

    private func advance() {
        let index = surahIds.firstIndex(of: id) ?? 0
        id = surahIds[(index + 1) % surahIds.count]
    }
}

#Preview("Looping") {
    PlayerSurahTitleLooping()
        .preferredColorScheme(.dark)
}

private struct PlayerSurahTitlePlayground: View {
    @State private var id = 1
    @State private var isErasing = false
    @State private var configuration = PlayerSurahTitle.defaultConfiguration

    var body: some View {
        VStack(spacing: 0) {
            PlayerSurahTitle(id: id, isErasing: isErasing, configuration: configuration)
                .frame(height: 220)
                .padding(.horizontal)

            Form {
                Section("Title") {
                    HStack {
                        Button("Prev") { id = id > 1 ? id - 1 : 114 }
                        Spacer()
                        Text("Surah \(id)").monospacedDigit()
                        Spacer()
                        Button("Next") { id = id < 114 ? id + 1 : 1 }
                    }
                    .buttonStyle(.borderless)
                    Toggle("Erase ahead of time", isOn: $isErasing)
                }

                AnimatedTextConfigurationSections(configuration: $configuration)
            }
        }
    }
}

#endif
