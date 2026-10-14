//
//  AnimatedText.swift
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

// swiftlint:disable file_length
import SwiftUI

enum SweepSide: CaseIterable {
    case left, right

    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

enum SweepCurve: CaseIterable {
    case linear, easeIn, easeOut, easeInOut

    var title: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease in"
        case .easeOut: "Ease out"
        case .easeInOut: "Ease in out"
        }
    }

    func animation(duration: Double) -> Animation {
        switch self {
        case .linear: .linear(duration: duration)
        case .easeIn: .easeIn(duration: duration)
        case .easeOut: .easeOut(duration: duration)
        case .easeInOut: .easeInOut(duration: duration)
        }
    }
}

enum SweepStyle: CaseIterable {
    /// A smooth gradient mask fades the text out and in.
    case gradient
    /// The text is erased along the path of its strokes, from the latest tip back to the first
    /// pixel, with the gradient only on the tip. Revealing runs the same path in reverse.
    case path

    var title: String {
        switch self {
        case .gradient: "Gradient"
        case .path: "Path"
        }
    }
}

struct AnimatedTextConfiguration {
    var style: SweepStyle = .gradient
    /// Edge of the text where the strokes start, in `.path` style. For Arabic this is the
    /// right edge, and the path ends at the leftmost tip.
    var pathStart: SweepSide = .right
    /// Length of the gradient at the stroke tip as a fraction of the whole path, in `.path`
    /// style.
    var pathBand: Double = 0.12
    /// Brightness of the glow in the pixels of the stroke tip, in `.path` style. 0 disables it.
    /// Unlike `glowRadius` it never spills outside the letters.
    var pathGlow: Double = 1
    /// Color the old glyphs take while the erasing band passes over them.
    var eraseTint: Color = .green
    /// Color the new glyphs take (and glow with) while the revealing band passes over them.
    var revealTint: Color = Color(red: 1, green: 0.78, blue: 0.2)
    /// 0 disables the tint, 1 is fully tinted at the middle of the band.
    var tintStrength: Double = 1
    /// Seconds for the old text to be erased when the text changes.
    var eraseDuration: Double = 3
    /// Seconds for the erase when it is started ahead of time with `isErasing`.
    var scheduledEraseDuration: Double = 3
    /// Seconds for the new text to be revealed.
    var revealDuration: Double = 3
    var eraseCurve: SweepCurve = .easeIn
    var revealCurve: SweepCurve = .easeOut
    /// Side the erasing band enters from.
    var eraseFrom: SweepSide = .left
    /// Side the revealing band enters from.
    var revealFrom: SweepSide = .right
    /// Width of the gradient band as a fraction of the text width.
    var bandFraction: Double = 0.4
    /// How much of the band the fade spans, 0...1. Lower values delete pixels more abruptly,
    /// closer to the middle of the band, instead of fading them across its whole width.
    var edgeSoftness: Double = 1
    /// Radius of the glow around glyphs being revealed. 0 disables it.
    var glowRadius: Double = 10
    /// Blur radius of a soft copy of the text that shows inside the band. 0 disables it.
    var blur: Double = 5
    /// Vertical offset in points of that soft copy.
    var drift: Double = 0
}

/// Text that changes with a gradient sweep: a soft band enters from one side, erasing the
/// current letters as it passes over them. Once everything is erased the text is swapped
/// and a second sweep, by default from the opposite side, reveals the new letters.
///
/// `eraseProgress` drives the erase directly (0 = intact, 1 = erased), for example from a
/// playhead that updates every frame. When the text then changes, the erase finishes from
/// wherever it got to, so a sweep that is already complete goes straight to the reveal.
///
/// Alternatively, setting `isErasing` starts the erase ahead of the text change, on its own clock, for
/// example when a track is about to end. The sweep is a normal animation, so it stays smooth
/// no matter how often the caller updates. Turning it off again before the text changes
/// brings the text back. When the text then changes, the erase finishes from wherever it got
/// to, so a sweep that is already complete goes straight to the reveal.
struct AnimatedText: View {
    let text: String
    var eraseProgress: Double?
    var isErasing: Bool
    var configuration: AnimatedTextConfiguration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.font) private var font

    @State private var displayed: String
    /// 0...1 erases `displayed`, 1...2 reveals it. 0 and 2 both mean fully visible.
    @State private var progress: Double = 0
    @State private var phase: Phase = .idle
    @State private var eraseDeadline: ContinuousClock.Instant?
    /// Order maps for `.path` style, by text and start edge.
    @State private var pathMaps: [PathMapRequest: Image] = [:]

    private enum Phase { case idle, erasing, revealing }

    private struct PathMapRequest: Hashable {
        let text: String
        let startsOnRight: Bool
        let isPath: Bool
    }

    private func pathMapRequest(for text: String) -> PathMapRequest {
        PathMapRequest(
            text: text,
            startsOnRight: configuration.pathStart == .right,
            isPath: configuration.style == .path
        )
    }

    init(
        _ text: String,
        eraseProgress: Double? = nil,
        isErasing: Bool = false,
        configuration: AnimatedTextConfiguration = AnimatedTextConfiguration()
    ) {
        self.text = text
        self.eraseProgress = eraseProgress
        self.isErasing = isErasing
        self.configuration = configuration
        _displayed = State(initialValue: text)
    }

    var body: some View {
        Text(displayed)
            .textRenderer(
                GradientSweepRenderer(
                    progress: progress,
                    configuration: configuration,
                    pathMap: pathMaps[pathMapRequest(for: displayed)]
                )
            )
            .accessibilityLabel(text)
            .task(id: text) { await transition() }
            .task(id: pathMapRequest(for: displayed)) { await ensurePathMap(for: displayed) }
            .task(id: pathMapRequest(for: text)) { await ensurePathMap(for: text) }
            .onChange(of: eraseProgress, initial: true) { _, value in
                // A pending text change or running sweep owns the progress from here on.
                guard let value, text == displayed, phase == .idle, !reduceMotion else { return }
                let target = min(max(value, 0), 1)
                // Small steps are per-frame updates and must not be eased; big ones are seeks.
                let isJump = abs(target - progress) > 0.1
                setProgress(target, animation: isJump ? .easeOut(duration: 0.35) : nil)
            }
            .onChange(of: isErasing) { _, erasing in
                // A pending text change owns the sweep from here on.
                guard text == displayed, !reduceMotion else { return }
                if erasing, phase == .idle {
                    phase = .erasing
                    let duration = configuration.scheduledEraseDuration
                    eraseDeadline = ContinuousClock.now + .seconds(duration)
                    setProgress(1, animation: configuration.eraseCurve.animation(duration: duration))
                } else if !erasing, phase == .erasing {
                    phase = .idle
                    eraseDeadline = nil
                    setProgress(0, animation: .easeOut(duration: 0.4))
                }
            }
    }

    /// Builds the order map for `text` once, so it is ready before the text is swapped in.
    private func ensurePathMap(for text: String) async {
        let request = pathMapRequest(for: text)
        guard request.isPath else { return }
        guard pathMaps[request] == nil else { return }
        let startsOnRight = request.startsOnRight
        guard let map = await StrokePathMap.makeImage(text: text, font: font, startsOnRight: startsOnRight)
        else { return }
        // Keep only the maps for the text on screen and the text about to replace it.
        let keep = [pathMapRequest(for: displayed), pathMapRequest(for: self.text), request]
        pathMaps = pathMaps.filter { keep.contains($0.key) }
        pathMaps[request] = map
    }

    private func transition() async {
        guard text != displayed || phase != .idle else { return }

        if reduceMotion {
            displayed = text
            return
        }

        // Interrupted mid-reveal: restart the erase from the beginning.
        if phase == .revealing { setProgress(0, animation: nil) }

        // Interrupted mid-erase: keep the running sweep and just wait for it. Otherwise
        // finish the erase from wherever the sweep already is.
        if phase != .erasing {
            phase = .erasing
            let duration = configuration.eraseDuration * (1 - progress)
            eraseDeadline = ContinuousClock.now + .seconds(duration)
            setProgress(1, animation: configuration.eraseCurve.animation(duration: duration))
        }

        let remaining = eraseDeadline.map { $0 - ContinuousClock.now } ?? .zero
        if remaining > .zero {
            guard (try? await Task.sleep(for: remaining)) != nil else { return }
        }

        // Everything is erased, so swapping the text is invisible.
        await ensurePathMap(for: text)
        guard !Task.isCancelled else { return }
        displayed = text
        phase = .revealing
        setProgress(
            2,
            animation: configuration.revealCurve.animation(duration: configuration.revealDuration)
        )

        guard (try? await Task.sleep(for: .seconds(configuration.revealDuration))) != nil else {
            return
        }

        phase = .idle
        eraseDeadline = nil
        setProgress(0, animation: nil)
    }

    private func setProgress(_ value: Double, animation: Animation?) {
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = animation == nil
        withTransaction(transaction) { progress = value }
    }
}

/// Where the band is for one frame, and the masks derived from it.
private struct Sweep {
    private static let maskSteps = 8
    /// Masks must cover all ink, which can extend far beyond the typographic bounds.
    static let region = Path(CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000))

    let isRevealing: Bool
    /// How far along the erase or reveal is, 0...1.
    let fraction: Double
    let tint: Color
    let bounds: CGRect
    let trailing: CGFloat
    let leading: CGFloat
    /// Sum of the text's horizontal extents, used to mirror positions for right-side sweeps.
    let mirror: CGFloat
    let fromRight: Bool
    private let softness: Double

    init(progress: Double, configuration: AnimatedTextConfiguration, bounds: CGRect) {
        isRevealing = progress > 1
        fraction = isRevealing ? progress - 1 : progress
        fromRight = (isRevealing ? configuration.revealFrom : configuration.eraseFrom) == .right
        tint = isRevealing ? configuration.revealTint : configuration.eraseTint
        softness = max(configuration.edgeSoftness, 0.05)
        self.bounds = bounds

        let band = max(bounds.width * CGFloat(configuration.bandFraction), 1)
        // Glyph ink can overhang the typographic bounds, especially in calligraphic fonts.
        // The band starts and ends a margin outside the text so nothing is left behind.
        let margin = max(bounds.width, bounds.height) * 0.15
        leading = bounds.minX - margin + fraction * (bounds.width + band + 2 * margin)
        trailing = leading - band
        mirror = bounds.minX + bounds.maxX
    }

    /// Position along the band: 0 at the trailing edge, 1 at the leading edge.
    /// Peaks in the middle of the band.
    func bump(_ location: Double) -> Double {
        sin(location * .pi)
    }

    /// Removal strength of the main text: erasing removes what the band has passed over.
    func removal(_ location: Double) -> Double {
        let spread = min(max(0.5 + (location - 0.5) / softness, 0), 1)
        let eased = spread * spread * (3 - 2 * spread)
        return isRevealing ? eased : 1 - eased
    }

    /// A horizontal gradient across the band, with one color per step of `value`.
    func shading(_ value: @escaping (Double) -> Color) -> GraphicsContext.Shading {
        // Sweeping from the right is the same as sweeping from the left over a mirrored layout.
        let start = fromRight ? mirror - trailing : trailing
        let end = fromRight ? mirror - leading : leading
        return .linearGradient(
            Gradient(stops: (0...Self.maskSteps).map { step in
                let location = Double(step) / Double(Self.maskSteps)
                return Gradient.Stop(color: value(location), location: location)
            }),
            startPoint: CGPoint(x: start, y: bounds.midY),
            endPoint: CGPoint(x: end, y: bounds.midY)
        )
    }
}

/// Masks the text with a moving gradient band. Working on pixels rather than glyph clusters
/// keeps the sweep smooth even when a font maps a whole word to a single glyph.
private struct GradientSweepRenderer: TextRenderer {
    /// Opacity of the soft copy that shows inside the band.
    private static let softCopyOpacity = 0.7

    var progress: Double
    var configuration: AnimatedTextConfiguration
    /// Order map for `.path` style. Until it is ready the gradient style is used.
    var pathMap: Image?

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard progress > 0, progress < 2 else {
            for line in layout { context.draw(line) }
            return
        }

        let bounds = layout.reduce(CGRect.null) { $0.union($1.typographicBounds.rect) }
        let sweep = Sweep(progress: progress, configuration: configuration, bounds: bounds)

        if configuration.style == .path, let pathMap {
            drawPathText(layout, sweep: sweep, pathMap: pathMap, in: &context)
            return
        }

        if sweep.isRevealing, configuration.glowRadius > 0 {
            drawGlow(layout, sweep: sweep, in: &context)
        }

        if configuration.blur > 0 || configuration.drift != 0 {
            drawSoftCopy(layout, sweep: sweep, in: &context)
        }
        drawMaskedText(layout, sweep: sweep, in: &context)
    }

    private func drawGlow(_ layout: Text.Layout, sweep: Sweep, in context: inout GraphicsContext) {
        context.drawLayer { outer in
            outer.drawLayer { inner in
                inner.addFilter(.shadow(
                    color: sweep.tint,
                    radius: CGFloat(configuration.glowRadius),
                    x: 0,
                    y: 0,
                    options: .shadowOnly
                ))
                for line in layout { inner.draw(line) }
            }
            outer.blendMode = .destinationOut
            outer.fill(Sweep.region, with: sweep.shading { .black.opacity(1 - sweep.bump($0)) })
        }
    }

    /// Hides everything past an edge that travels along the stroke path. Erasing moves the edge
    /// from the latest tip to the first pixel, and revealing moves it back. The glow lives in
    /// the pixels of the fading tip itself.
    private func drawPathText(
        _ layout: Text.Layout,
        sweep: Sweep,
        pathMap: Image,
        in context: inout GraphicsContext
    ) {
        let band = configuration.pathBand
        let along = sweep.isRevealing ? sweep.fraction : 1 - sweep.fraction
        let shader = ShaderLibrary.sweepPath(
            .image(pathMap),
            .float2(sweep.bounds.origin),
            .float2(sweep.bounds.size),
            .float((1 + band) * along),
            .float(band),
            .float(configuration.tintStrength),
            .float(configuration.pathGlow),
            .color(sweep.tint)
        )
        context.drawLayer { layer in
            layer.addFilter(.colorShader(shader))
            for line in layout { layer.draw(line) }
        }
    }

    private func drawSoftCopy(_ layout: Text.Layout, sweep: Sweep, in context: inout GraphicsContext) {
        context.drawLayer { outer in
            outer.drawLayer { inner in
                inner.translateBy(x: 0, y: CGFloat(configuration.drift))
                if configuration.blur > 0 {
                    inner.addFilter(.blur(radius: CGFloat(configuration.blur)))
                }
                for line in layout { inner.draw(line) }
            }
            // The soft copy never outlasts the main text, so deleted pixels do not linger.
            outer.blendMode = .destinationOut
            outer.fill(
                Sweep.region,
                with: sweep.shading {
                    .black.opacity(1 - sweep.bump($0) * (1 - sweep.removal($0)) * Self.softCopyOpacity)
                }
            )
            outer.blendMode = .sourceAtop
            outer.fill(Sweep.region, with: tintShading(sweep))
        }
    }

    private func drawMaskedText(_ layout: Text.Layout, sweep: Sweep, in context: inout GraphicsContext) {
        context.drawLayer { layer in
            for line in layout { layer.draw(line) }
            layer.blendMode = .destinationOut
            layer.fill(Sweep.region, with: sweep.shading { .black.opacity(sweep.removal($0)) })
            layer.blendMode = .sourceAtop
            layer.fill(Sweep.region, with: tintShading(sweep))
        }
    }

    private func tintShading(_ sweep: Sweep) -> GraphicsContext.Shading {
        sweep.shading { sweep.tint.opacity(sweep.bump($0) * configuration.tintStrength) }
    }
}

// MARK: - Preview

#if DEBUG
/// Form sections with a control for every `AnimatedTextConfiguration` setting. Meant to sit
/// inside a `Form` in previews, next to whatever view is being tuned.
struct AnimatedTextConfigurationSections: View {
    @Binding var configuration: AnimatedTextConfiguration

    var body: some View {
        Section("Style") {
            Picker("Style", selection: $configuration.style) {
                ForEach(SweepStyle.allCases, id: \.self) { Text($0.title) }
            }
            .pickerStyle(.segmented)
            sidePicker("Path starts at", selection: $configuration.pathStart)
            slider("Path tip length", value: $configuration.pathBand, range: 0.02...0.5)
            slider("Path tip glow", value: $configuration.pathGlow, range: 0...3)
        }

        Section("Erase") {
            slider("Duration", value: $configuration.eraseDuration, range: 0.1...6)
            slider(
                "Ahead-of-time duration",
                value: $configuration.scheduledEraseDuration,
                range: 0.1...8
            )
            sidePicker("From", selection: $configuration.eraseFrom)
            curvePicker("Curve", selection: $configuration.eraseCurve)
            ColorPicker("Tint", selection: $configuration.eraseTint, supportsOpacity: false)
        }

        Section("Reveal") {
            slider("Duration", value: $configuration.revealDuration, range: 0.1...6)
            sidePicker("From", selection: $configuration.revealFrom)
            curvePicker("Curve", selection: $configuration.revealCurve)
            ColorPicker("Tint", selection: $configuration.revealTint, supportsOpacity: false)
            slider("Glow radius", value: $configuration.glowRadius, range: 0...30, step: 1)
        }

        Section("Band") {
            slider("Width fraction", value: $configuration.bandFraction, range: 0.05...1)
            slider("Edge softness", value: $configuration.edgeSoftness, range: 0.05...1)
            slider("Blur", value: $configuration.blur, range: 0...20, step: 0.5)
            slider("Drift", value: $configuration.drift, range: -30...30, step: 1)
            slider("Tint strength", value: $configuration.tintStrength, range: 0...1)
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.05
    ) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step)
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0...2)))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private func sidePicker(_ title: String, selection: Binding<SweepSide>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SweepSide.allCases, id: \.self) { Text($0.title) }
        }
        .pickerStyle(.segmented)
    }

    private func curvePicker(_ title: String, selection: Binding<SweepCurve>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SweepCurve.allCases, id: \.self) { Text($0.title) }
        }
    }
}

private struct AnimatedTextPlayground: View {
    private let presets = [
        "Mishary Alafasy",
        "Abdul Basit Abdul Samad",
        "بسم الله الرحمن الرحيم",
        "Now Playing"
    ]

    @State private var index = 0
    @State private var text = "Mishary Alafasy"
    @State private var draft = ""
    @State private var fontSize = 34.0
    @State private var isErasing = false
    @State private var configuration = AnimatedTextConfiguration()

    var body: some View {
        VStack(spacing: 0) {
            AnimatedText(text, isErasing: isErasing, configuration: configuration)
                .font(.system(size: fontSize, weight: .bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(.horizontal)

            Form {
                Section("Text") {
                    Button("Next preset") {
                        index = (index + 1) % presets.count
                        text = presets[index]
                    }
                    TextField("Custom text, press return", text: $draft)
                        .onSubmit { if !draft.isEmpty { text = draft } }
                    LabeledContent("Font size") {
                        Slider(value: $fontSize, in: 14...80, step: 1)
                    }
                    Toggle("Erase ahead of time", isOn: $isErasing)
                }

                AnimatedTextConfigurationSections(configuration: $configuration)
            }
        }
    }
}

#Preview("Playground") {
    AnimatedTextPlayground()
}
#endif
