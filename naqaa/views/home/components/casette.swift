import SwiftUI

// MARK: - Deterministic grain (seeded LCG so layout redraws don't flicker)

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64 = 0xDEADBEEF) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / 2147483648.0
    }
}

struct GrainOverlay: View {
    var density: Double  = 0.16
    var maxOpacity: Double = 0.08
    var seed: UInt64 = 0xDEADBEEF

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: seed)
            let n = Int(size.width * size.height * density)
            for _ in 0..<n {
                let x    = CGFloat(rng.next()) * size.width
                let y    = CGFloat(rng.next()) * size.height
                let r    = CGFloat(rng.next()) * 1.3 + 0.2
                let a    = rng.next() * maxOpacity
                let dark = rng.next() < 0.30
                let col: Color = dark ? .black.opacity(a * 0.55) : .white.opacity(a)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(col)
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
    }
}

// MARK: - Main View

struct CassetteView: View {
    var isDark: Bool
    var isPlaying: Bool
    var titleText: String
    var subtitleText: String
    
    let pastelLavender = Color(red: 0.48, green: 0.38, blue: 0.72)
    let pastelBlue     = Color(red: 0.36, green: 0.55, blue: 0.78)

    var body: some View {
        ZStack {
            // Adaptive Ambient Shadow Drop
            RoundedRectangle(cornerRadius: 14)
                .fill(isDark ? Color.black.opacity(0.6) : Color(red: 0.10, green: 0.16, blue: 0.28).opacity(0.12))
                .frame(width: 384, height: 234)
                .offset(x: 2, y: 12)
                .blur(radius: 16)

            // FRONT FACE
            ZStack(alignment: .center) {
                // Glass Base Container
                GlassShell(isDark: isDark)

                // Integrated Premium Screws
                ScrewLayout(isDark: isDark)
                    .opacity(isDark ? 0.4 : 0.6)

                // Inset paper label (CassetteLabelShape)
                ZStack(alignment: .top) {
                    CassetteLabelShape()
                        .fill(
                            LinearGradient(
                                colors: isDark
                                    ? [.white.opacity(0.08), .white.opacity(0.03)]
                                    : [.white.opacity(0.4), .white.opacity(0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            CassetteLabelShape()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .black.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // High visibility sculpted text inside the top of the label plate
                    VStack(spacing: 3) {
                        SculptedText(text: titleText, isDark: isDark, font: .system(size: 14, weight: .bold, design: .monospaced))
                        SculptedText(text: subtitleText, isDark: isDark, font: .system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.top, 14)
                }
                .frame(width: 336, height: 180)
                .offset(y: -2)

                // Re-scaled Clean Center Window Component Layer
                CenterTapeWindow(
                    isDark: isDark,
                    isPlaying: isPlaying,
                    pastelA: pastelLavender,
                    pastelB: pastelBlue
                )

                // Foot Bottom Guard Base
                VStack {
                    Spacer()
                    BottomTaperedGuard(
                        isDark: isDark,
                        glassBase: pastelLavender.opacity(isDark ? 0.2 : 0.4),
                        pastelAccent: pastelBlue
                    )
                }
            }
            .frame(width: 380, height: 230)
        }
    }
}

// MARK: - Sculpted (Debossed) High-Contrast Text Engine

struct SculptedText: View {
    var text: String
    var isDark: Bool
    var font: Font
    
    var body: some View {
        ZStack {
            // 1. Ambient Deep Internal Shadow Edge
            Text(text)
                .font(font)
                .tracking(2.0)
                .foregroundColor(isDark ? Color.black.opacity(0.9) : Color.black.opacity(0.4))
                .offset(y: -1.0)
            
            // 2. High Vis Specular Bezel Highlight
            Text(text)
                .font(font)
                .tracking(2.0)
                .foregroundColor(isDark ? Color.white.opacity(0.45) : Color.white.opacity(0.95))
                .offset(y: 1.0)
            
            // 3. Core Structural Engraving Floor Color
            Text(text)
                .font(font)
                .tracking(2.0)
                .foregroundColor(isDark ? Color.black.opacity(0.75) : Color(white: 0.02).opacity(0.7))
                .blendMode(isDark ? .multiply : .normal)
        }
    }
}

// MARK: - Glass Shell (Premium PBR)

struct GlassShell: View {
    var isDark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color.black.opacity(0.4), Color.black.opacity(0.2)]
                            : [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isDark ? 0.45 : 0.7),
                            .white.opacity(0.1),
                            .black.opacity(isDark ? 0.55 : 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            GrainOverlay(density: 0.22, maxOpacity: isDark ? 0.12 : 0.06, seed: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Cassette Label Shape

struct CassetteLabelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bevel        = CGFloat(10)
        let bottomRadius = CGFloat(8)
        let bottomInset  = CGFloat(20)

        path.move(to: CGPoint(x: rect.minX + bevel, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bevel, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bevel))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomInset - bottomRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomInset - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomInset))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomInset - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bevel))
        path.closeSubpath()
        return path
    }
}

// MARK: - Center Window & Fixed Spools

struct CenterTapeWindow: View {
    var isDark: Bool
    var isPlaying: Bool
    let pastelA: Color
    let pastelB: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color.black.opacity(0.85), Color(white: 0.05).opacity(0.9)]
                            : [Color(white: 0.1).opacity(0.15), Color(white: 0.02).opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .fill(pastelB.opacity(isDark ? 0.06 : 0.12))
                        .blur(radius: 6)
                        .offset(y: -8)
                )
                .frame(width: 196, height: 60)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.black.opacity(0.4), .white.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )

            HStack(spacing: 8) {
                SpoolWheel(isDark: isDark, isPlaying: isPlaying, pastelAccent: pastelA)

                // Balanced Ribbon Segment
                Rectangle()
                    .fill(isDark ? Color.black.opacity(0.65) : Color.black.opacity(0.8))
                    .frame(width: 46, height: 34)
                    .overlay(
                        VStack(spacing: 4) {
                            ForEach(0..<4) { i in
                                Rectangle()
                                    .fill(i == 1 ? pastelA.opacity(0.35) : Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }
                        .padding(.horizontal, 4)
                    )

                SpoolWheel(isDark: isDark, isPlaying: isPlaying, pastelAccent: pastelB)
            }
        }
    }
}

// MARK: - Spool Wheel (Restored Large Circles)

struct SpoolWheel: View {
    var isDark: Bool
    var isPlaying: Bool
    let pastelAccent: Color
    
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            pastelAccent.opacity(isDark ? 0.4 : 0.6),
                            pastelAccent.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48) // Fixed larger diameter
                .overlay(Circle().fill(.thinMaterial).frame(width: 48, height: 48))
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(isDark ? 0.3 : 0.1), radius: 2, y: 1)

            Circle()
                .stroke(
                    isDark ? Color.black.opacity(0.8) : Color.black.opacity(0.6),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [3, 4])
                )
                .frame(width: 28, height: 28)

            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .offset(x: -1.5, y: -1.5)
                )
        }
        .rotationEffect(.degrees(rotationAngle))
        .onChange(of: isPlaying, initial: true) { _, playing in
            if playing {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    rotationAngle = 0.0
                }
            }
        }
    }
}

// MARK: - Bottom Tapered Guard

struct BottomTaperedGuard: View {
    var isDark: Bool
    let glassBase: Color
    let pastelAccent: Color

    var body: some View {
        ZStack {
            PolygonShape()
                .fill(
                    LinearGradient(
                        colors: [glassBase, pastelAccent.opacity(isDark ? 0.1 : 0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 264, height: 46)
                .overlay(PolygonShape().fill(.ultraThinMaterial))
                .overlay(
                    PolygonShape()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(isDark ? 0.2 : 0.5), .black.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    HStack {
                        Circle().fill(isDark ? Color(white: 0.08) : Color(white: 0.25)).frame(width: 8, height: 8)
                        Spacer()
                        Circle().fill(isDark ? Color(white: 0.08) : Color(white: 0.25)).frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, 42)
                    .offset(y: -5)
                )
                .overlay(
                    HStack(spacing: 0) {
                        Circle().fill(isDark ? Color(white: 0.05) : Color(white: 0.2)).frame(width: 10, height: 10)
                        Spacer()
                        Circle().fill(isDark ? Color(white: 0.05) : Color(white: 0.2)).frame(width: 10, height: 10)
                    }
                    .padding(.horizontal, 22)
                    .offset(y: 6)
                )
        }
    }
}

// MARK: - Polygon Shape

struct PolygonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 14, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 14, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mechanical Fasteners

struct ScrewLayout: View {
    var isDark: Bool
    
    var body: some View {
        VStack {
            HStack {
                MiniScrew(isDark: isDark).offset(x: -3, y: -5)
                Spacer()
                MiniScrew(isDark: isDark).offset(x: 3, y: -5)
            }
            Spacer()
            HStack {
                MiniScrew(isDark: isDark).offset(x: -3, y: 5)
                Spacer()
                MiniScrew(isDark: isDark).offset(x: 3, y: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }
}

struct MiniScrew: View {
    var isDark: Bool
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isDark
                        ? [Color(white: 0.4), Color(white: 0.15)]
                        : [Color(white: 0.85), Color(white: 0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.5))
            .overlay(
                Rectangle()
                    .fill(isDark ? Color.black.opacity(0.8) : Color.black.opacity(0.6))
                    .frame(width: 7, height: 1.5)
                    .rotationEffect(.degrees(45))
            )
            .shadow(color: .white.opacity(isDark ? 0.05 : 0.3), radius: 0.5, x: 0, y: 0.5)
    }
}

// MARK: - Interactive Preview Tester

struct CassetteView_Previews: PreviewProvider {
    struct PreviewTester: View {
        @State private var darkTheme = true
        @State private var playing = true
        
        var body: some View {
            VStack(spacing: 30) {
                ZStack {
                    if darkTheme {
                        Color(red: 0.08, green: 0.09, blue: 0.13).ignoresSafeArea()
                    } else {
                        Color(red: 0.94, green: 0.95, blue: 0.97).ignoresSafeArea()
                    }
                    
                    CassetteView(
                        isDark: darkTheme,
                        isPlaying: playing,
                        titleText: "عبدالباسط",
                        subtitleText: "سورة البقرة"
                    )
                }
                .frame(width: 420, height: 280)
                .cornerRadius(24)
                .shadow(radius: 10)
                
                VStack(spacing: 12) {
                    Toggle("Obsidian Dark Plate Mode", isOn: $darkTheme)
                    Toggle("Spin Internal Tape Spools", isOn: $playing)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .frame(width: 320)
            }
        }
    }

    static var previews: some View {
        PreviewTester()
    }
}
