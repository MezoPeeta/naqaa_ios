import SwiftUI

/// A premium Islamic geometric pattern that fades in from the top edge of
/// the player. Shape, gradient style, height and color are all adjustable
/// so the motif can be tuned per screen. See the gallery preview at the
/// bottom of this file to try combinations live.
struct PlayerTopPattern: View {
    var height: CGFloat = 180
    var color: Color = .accentColor
    var tileSize: CGFloat = 52
    var shape: PatternShape = .eightPointStar
    var gradientStyle: PatternGradientStyle = .linear

    var body: some View {
        Canvas { context, size in
            let rowStep = tileSize * 0.75
            let rows = Int(ceil(size.height / rowStep)) + 1
            let columns = Int(ceil(size.width / tileSize)) + 1
            let outerRadius = tileSize * 0.48
            let innerRadius = tileSize * 0.2

            for row in 0..<rows {
                let centerY = CGFloat(row) * rowStep
                let rowOffset = row.isMultiple(of: 2) ? 0 : tileSize / 2
                let rowFade = max(0, 1 - (centerY / size.height) * 0.85)

                for column in 0..<columns {
                    let centerX = CGFloat(column) * tileSize + rowOffset - tileSize / 2
                    let center = CGPoint(x: centerX, y: centerY)

                    let motif = shape.path(center: center, outerRadius: outerRadius, innerRadius: innerRadius)
                    let shading = gradientStyle.shading(color: color, center: center, radius: outerRadius)

                    var motifContext = context
                    motifContext.opacity = rowFade

                    motifContext.fill(motif, with: shading, style: FillStyle(eoFill: true))
                    motifContext.stroke(motif, with: .color(color.opacity(0.9)), lineWidth: 1.1)

                    let core = Path(ellipseIn: CGRect(
                        x: center.x - innerRadius * 0.35,
                        y: center.y - innerRadius * 0.35,
                        width: innerRadius * 0.7,
                        height: innerRadius * 0.7
                    ))
                    motifContext.fill(core, with: .color(color.opacity(0.95)))
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .blendMode(.plusLighter)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.7), location: 0.55),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: color.opacity(0.35), radius: 12, y: 6)
        .allowsHitTesting(false)
    }
}

/// The tessellating motif drawn at each tile center.
enum PatternShape: String, CaseIterable, Identifiable {
    case eightPointStar = "8-Point Star"
    case sixPointStar = "6-Point Star (Hexagram)"
    case fourPointStar = "4-Point Star (Rub el Hizb)"
    case twelvePointStar = "12-Point Star"
    case hexagon = "Hexagon"
    case octagon = "Octagon"

    var id: String { rawValue }

    func path(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> Path {
        switch self {
        case .eightPointStar:
            return Self.star(center: center, points: 8, outerRadius: outerRadius, innerRadius: innerRadius)
        case .sixPointStar:
            return Self.star(center: center, points: 6, outerRadius: outerRadius, innerRadius: innerRadius)
        case .fourPointStar:
            return Self.star(center: center, points: 4, outerRadius: outerRadius, innerRadius: innerRadius)
        case .twelvePointStar:
            return Self.star(center: center, points: 12, outerRadius: outerRadius, innerRadius: innerRadius * 1.3)
        case .hexagon:
            return Self.polygon(center: center, sides: 6, radius: outerRadius)
        case .octagon:
            return Self.polygon(center: center, sides: 8, radius: outerRadius)
        }
    }

    private static func star(center: CGPoint, points: Int, outerRadius: CGFloat, innerRadius: CGFloat) -> Path {
        var path = Path()
        let angleStep = Double.pi * 2 / Double(points * 2)

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = angleStep * Double(index) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func polygon(center: CGPoint, sides: Int, radius: CGFloat) -> Path {
        var path = Path()
        let angleStep = Double.pi * 2 / Double(sides)

        for index in 0..<sides {
            let angle = angleStep * Double(index) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// The shading style applied to each drawn motif.
enum PatternGradientStyle: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case radial = "Radial"
    case angular = "Angular"
    case solid = "Solid"

    var id: String { rawValue }

    func shading(color: Color, center: CGPoint, radius: CGFloat) -> GraphicsContext.Shading {
        switch self {
        case .linear:
            return .linearGradient(
                Gradient(colors: [color.opacity(0.9), color.opacity(0.45)]),
                startPoint: CGPoint(x: center.x, y: center.y - radius),
                endPoint: CGPoint(x: center.x, y: center.y + radius)
            )
        case .radial:
            return .radialGradient(
                Gradient(colors: [color.opacity(0.95), color.opacity(0.35)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        case .angular:
            return .conicGradient(
                Gradient(colors: [
                    color.opacity(0.9),
                    color.opacity(0.4),
                    color.opacity(0.9),
                    color.opacity(0.4),
                    color.opacity(0.9)
                ]),
                center: center
            )
        case .solid:
            return .color(color.opacity(0.7))
        }
    }
}

// MARK: - Interactive Gallery Preview

#if DEBUG
private struct PlayerTopPatternGallery: View {
    @State private var shape: PatternShape = .eightPointStar
    @State private var gradientStyle: PatternGradientStyle = .linear
    @State private var color: Color = .yellow
    @State private var tileSize: CGFloat = 52
    @State private var height: CGFloat = 200

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                PlayerTopPattern(
                    height: height,
                    color: color,
                    tileSize: tileSize,
                    shape: shape,
                    gradientStyle: gradientStyle
                )
                Spacer()
            }

            controls
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, height + 16)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Shape", selection: $shape) {
                ForEach(PatternShape.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Picker("Gradient", selection: $gradientStyle) {
                ForEach(PatternGradientStyle.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            ColorPicker("Color", selection: $color)

            VStack(alignment: .leading) {
                Text("Tile size: \(Int(tileSize))")
                Slider(value: $tileSize, in: 20...100)
            }

            VStack(alignment: .leading) {
                Text("Height: \(Int(height))")
                Slider(value: $height, in: 80...320)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
    }
}

#Preview("Interactive Gallery") {
    PlayerTopPatternGallery()
}

#Preview("All Shapes") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(PatternShape.allCases) { shape in
                VStack(spacing: 8) {
                    Text(shape.rawValue)
                        .foregroundStyle(.white)
                        .font(.caption)
                    PlayerTopPattern(height: 140, color: .yellow, shape: shape, gradientStyle: .radial)
                }
            }
        }
        .padding(.vertical)
    }
    .background(.black)
}

#Preview("All Gradients") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(PatternGradientStyle.allCases) { style in
                VStack(spacing: 8) {
                    Text(style.rawValue)
                        .foregroundStyle(.white)
                        .font(.caption)
                    PlayerTopPattern(height: 140, color: .yellow, shape: .eightPointStar, gradientStyle: style)
                }
            }
        }
        .padding(.vertical)
    }
    .background(.black)
}
#endif
