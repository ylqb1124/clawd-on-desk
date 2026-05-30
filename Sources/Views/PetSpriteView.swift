import SwiftUI
import Darwin

struct PetSpriteView: View {
    let state: PetState
    let frame: Int

    var body: some View {
        ClawdSprite(state: state, frame: frame)
            .frame(width: 100, height: 80)
    }
}

// MARK: - Clawd Canvas Sprite

struct ClawdSprite: View {
    let state: PetState
    let frame: Int

    // Sub-pixel grid: each entry is (col, row) in 2x2 sub-pixel space
    // Shape (col 0..8, row 0..5 in sub-pixel coords):
    //  ▐▛███▜▌   → row 0-1
    // ▝▜█████▛▘  → row 2-3
    //   ▘▘ ▝▝   → row 4-5
    //
    // Each Unicode block char occupies 1 char-col × 1 char-row = 2 sub-px wide × 2 sub-px tall
    // char grid is 9 cols × 3 rows → sub-pixel grid is 18 × 6
    private static let bodyPixels: [(Int, Int)] = {
        // (charCol, charRow) → sub-pixel offsets per character type
        // █ full
        let full = [(0,0),(1,0),(0,1),(1,1)]
        // ▌ left half
        let left = [(0,0),(0,1)]
        // ▐ right half
        let right = [(1,0),(1,1)]
        // ▛ top-left + bottom-left + top-right (3/4, missing bottom-right)
        let tl3 = [(0,0),(0,1),(1,0)]
        // ▜ top-left + top-right + bottom-right (3/4, missing bottom-left)
        let tr3 = [(0,0),(1,0),(1,1)]
        // ▘ top-left quadrant
        let tl1 = [(0,0)]
        // ▝ top-right quadrant
        let tr1 = [(1,0)]

        // Row 0: " ▐▛███▜▌" (chars at col 1..7, col 0 is space)
        // char positions: col1=▐, col2=▛, col3=█, col4=█, col5=█, col6=▜, col7=▌
        var pixels: [(Int,Int)] = []
        func add(_ charCol: Int, _ charRow: Int, _ offsets: [(Int,Int)]) {
            for (dx, dy) in offsets {
                pixels.append((charCol * 2 + dx, charRow * 2 + dy))
            }
        }
        // Row 0
        add(1, 0, right); add(2, 0, tl3); add(3, 0, full); add(4, 0, full); add(5, 0, full); add(6, 0, tr3); add(7, 0, left)
        // Row 1: "▝▜█████▛▘" (cols 0..8)
        add(0, 1, tr1); add(1, 1, tr3); add(2, 1, full); add(3, 1, full); add(4, 1, full); add(5, 1, full); add(6, 1, full); add(7, 1, tl3); add(8, 1, tl1)
        // Row 2: "  ▘▘ ▝▝" (cols 2,3 = ▘▘, col 5,6 = ▝▝)
        add(2, 2, tl1); add(3, 2, tl1); add(5, 2, tr1); add(6, 2, tr1)
        return pixels
    }()

    @State private var thinkingRotation: Double = 0

    private static let eyePositions: [(Int, Int)] = [(5,1), (12,1)]

    private func eyePositions(for state: PetState, frame: Int) -> [(Int, Int)] {
        switch state {
        case .sleeping:
            return [(4,1),(5,1),(6,1), (11,1),(12,1),(13,1)]
        case .error:
            return [(4,1),(6,1),(5,2), (11,1),(13,1),(12,2)]
        case .thinking:
            return [(5,0),(12,0)]
        default:
            return Self.eyePositions
        }
    }

    var body: some View {
        ZStack {
            backgroundEffect
            bodyCanvas
                .scaleEffect(bodyScale)
                .offset(x: bodyOffsetX, y: bodyOffsetY)
                .rotationEffect(.degrees(state == .thinking ? thinkingRotation : 0))
                .shadow(color: shadowColor, radius: shadowRadius)
            foregroundEffect
        }
        .onAppear {
            if state == .thinking { startThinkingRotation() }
        }
        .onChange(of: state) { newState in
            if newState == .thinking {
                startThinkingRotation()
            } else {
                thinkingRotation = 0
            }
        }
    }

    private func startThinkingRotation() {
        thinkingRotation = 0
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            thinkingRotation = 360
        }
    }

    private static let pxW: CGFloat = 5
    private static let pxH: CGFloat = 8
    private static let canvasW = pxW * 18
    private static let canvasH = pxH * 6

    private var bodyCanvas: some View {
        Canvas { ctx, size in
            let pxW = Self.pxW
            let pxH = Self.pxH
            let offsetX = (size.width  - pxW * 18) / 2
            let offsetY = (size.height - pxH * 6)  / 2
            let color = GraphicsContext.Shading.color(colorForState)
            for (col, row) in Self.bodyPixels {
                let rect = CGRect(
                    x: offsetX + CGFloat(col) * pxW,
                    y: offsetY + CGFloat(row) * pxH,
                    width: pxW, height: pxH
                )
                ctx.fill(Path(rect), with: color)
            }

            // Eyes
            let eyeColor = GraphicsContext.Shading.color(eyeColor)
            for (col, row) in eyePositions(for: state, frame: frame) {
                let rect = CGRect(
                    x: offsetX + CGFloat(col) * pxW,
                    y: offsetY + CGFloat(row) * pxH,
                    width: pxW, height: pxH
                )
                ctx.fill(Path(rect), with: eyeColor)
            }
        }
        .frame(width: Self.canvasW, height: Self.canvasH)
    }

    private var eyeColor: Color { .black.opacity(0.9) }

    // MARK: - Trig Helpers
    private func sinVal(_ v: Double) -> CGFloat { CGFloat(Darwin.sin(v)) }
    private func cosVal(_ v: Double) -> CGFloat { CGFloat(Darwin.cos(v)) }

    // MARK: - Background Effects
    @ViewBuilder
    private var backgroundEffect: some View {
        switch state {
        case .searching:
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color(red: 0.3, green: 0.3, blue: 0.85).opacity(0.4), lineWidth: 2)
                .frame(width: 55, height: 55)
                .rotationEffect(.degrees(Double(frame) * 90))
        case .idle:
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.4, green: 0.65, blue: 0.95).opacity(0.35))
                    .frame(width: 3, height: 8)
                    .offset(y: -28)
                    .rotationEffect(.degrees(Double(i) * 60 + Double(frame) * 15))
            }
        case .installing:
            Circle()
                .trim(from: 0, to: progressAmount)
                .stroke(Color(red: 0.6, green: 0.35, blue: 0.9).opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
        case .subAgent:
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.3, green: 0.85, blue: 0.7).opacity(0.6))
                    .frame(width: 8, height: 8)
                    .overlay(HStack(spacing: 2) {
                        Circle().fill(.white).frame(width: 1.5, height: 1.5)
                        Circle().fill(.white).frame(width: 1.5, height: 1.5)
                    })
                    .offset(x: cosVal(Double(frame) * .pi / 2 + Double(i) * 2.094) * 30,
                            y: sinVal(Double(frame) * .pi / 2 + Double(i) * 2.094) * 30)
            }
        case .testing:
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.1, green: 0.8, blue: 0.75).opacity(0.5))
                .frame(width: 50, height: 2)
                .offset(y: -20 + CGFloat(Double(frame) / 4.0) * 10)
        case .sleeping:
            ForEach(0..<2, id: \.self) { i in
                Text("z")
                    .font(.system(size: CGFloat(6 + i * 2), weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.3 + Double((frame + i) % 4) / 4.0 * 0.5))
                    .offset(x: CGFloat(10 + i * 8),
                            y: -20 - CGFloat(i) * 10 + sinVal(Double(frame + i) * .pi / 2) * 3)
            }
        case .attention:
            Circle()
                .trim(from: 0, to: 0.35)
                .stroke(Color.red.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(Double(frame) * 30))
        default:
            EmptyView()
        }
    }

    // MARK: - Foreground Effects
    @ViewBuilder
    private var foregroundEffect: some View {
        switch state {
        case .typing:
            ForEach(0..<2, id: \.self) { i in
                let phase = Double((frame + i * 2) % 4) / 4.0
                Circle()
                    .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(max(0, 0.6 - phase)), lineWidth: 1)
                    .frame(width: 30 + CGFloat(phase) * 25, height: 30 + CGFloat(phase) * 25)
                    .offset(y: 5)
            }
        case .celebrate:
            ForEach(0..<6, id: \.self) { i in
                let r = CGFloat(Double(frame) * 4.0)
                let angle = Double(i) * .pi / 3
                Circle()
                    .fill([Color.yellow, .orange, .pink, .cyan, .green, .purple][i % 6])
                    .frame(width: 4, height: 4)
                    .offset(x: cosVal(angle) * r, y: sinVal(angle) * r)
                    .opacity(max(0, 1.0 - Double(frame) / 8.0))
            }
        case .error:
            if frame % 3 == 0 {
                Path { p in
                    p.move(to: CGPoint(x: 35, y: 30))
                    p.addLine(to: CGPoint(x: 38, y: 35))
                    p.addLine(to: CGPoint(x: 36, y: 40))
                    p.addLine(to: CGPoint(x: 39, y: 45))
                }
                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                .offset(x: 5, y: -10)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Body Properties
    private var bodyScale: CGFloat {
        switch state {
        case .sleeping: return 1.0 + sinVal(Double(frame) * .pi / 2) * 0.05
        case .celebrate: return 1.0 + sinVal(Double(frame) * .pi / 4) * 0.1
        case .attention: return 1.0 + (frame % 2 == 0 ? 0.05 : 0)
        default: return 1.0
        }
    }
    private var bodyOffsetX: CGFloat {
        guard state == .error else { return 0 }
        let s = frame % 3
        return s == 0 ? -5 : s == 1 ? 5 : 0
    }
    private var bodyOffsetY: CGFloat {
        state == .celebrate ? -abs(sinVal(Double(frame) * .pi / 4)) * 8 : 0
    }
    private var shadowColor: Color {
        state.isUrgent ? .red.opacity(0.6) : colorForState.opacity(0.3)
    }
    private var shadowRadius: CGFloat {
        switch state {
        case .attention: return CGFloat(6 + (frame % 2) * 4)
        case .celebrate: return 10
        default: return 6
        }
    }
    private var progressAmount: CGFloat {
        CGFloat(frame) / CGFloat(max(1, PetState.installing.frameCount))
    }

    // MARK: - Color
    private var colorForState: Color {
        switch state {
        case .sleeping:   return Color(red: 0.55, green: 0.55, blue: 0.6)
        case .idle:       return Color(red: 0.4,  green: 0.65, blue: 0.95)
        case .thinking:   return Color(red: 0.95, green: 0.65, blue: 0.15)
        case .typing:     return Color(red: 0.2,  green: 0.8,  blue: 0.4)
        case .building:   return Color(red: 0.9,  green: 0.4,  blue: 0.2)
        case .installing: return Color(red: 0.6,  green: 0.35, blue: 0.9)
        case .testing:    return Color(red: 0.1,  green: 0.8,  blue: 0.75)
        case .error:      return Color(red: 0.9,  green: 0.2,  blue: 0.25)
        case .celebrate:  return Color(red: 1.0,  green: 0.85, blue: 0.1)
        case .attention:  return Color(red: 0.95, green: 0.2,  blue: 0.3)
        case .searching:  return Color(red: 0.3,  green: 0.3,  blue: 0.85)
        case .subAgent:   return Color(red: 0.3,  green: 0.85, blue: 0.7)
        }
    }
}
