import SwiftUI
import Darwin

/// Renders the pet sprite with rich state-driven animations
struct PetSpriteView: View {
    let state: PetState
    let frame: Int

    var body: some View {
        MinimalSprite(state: state, frame: frame)
            .frame(width: 80, height: 80)
    }
}

// MARK: - Minimal Sprite with Rich Animations
struct MinimalSprite: View {
    let state: PetState
    let frame: Int

    var body: some View {
        ZStack {
            // Background effects layer
            backgroundEffect

            // Main body
            Circle()
                .fill(colorForState)
                .frame(width: bodySize, height: bodySize)
                .shadow(color: shadowColor, radius: shadowRadius)
                .scaleEffect(bodyScale)
                .offset(y: bodyOffsetY)
                .rotationEffect(bodyRotation)

            // Face
            faceView
                .offset(y: bodyOffsetY)

            // Foreground effects layer
            foregroundEffect
        }
    }

    // MARK: - Trig Helpers

    private func sinVal(_ v: Double) -> CGFloat {
        CGFloat(Darwin.sin(v))
    }

    private func cosVal(_ v: Double) -> CGFloat {
        CGFloat(Darwin.cos(v))
    }

    // MARK: - Face

    @ViewBuilder
    private var faceView: some View {
        switch state {
        case .sleeping:
            // Closed eyes + small peaceful mouth
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.7))
                        .frame(width: 5, height: 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.7))
                        .frame(width: 5, height: 2)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.5))
                    .frame(width: 4, height: 1.5)
            }
        case .thinking:
            // Eyes looking up + short mouth
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                        .offset(y: -1)
                    Circle().fill(.white).frame(width: 4, height: 4)
                        .offset(y: -1)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 4, height: 1.5)
            }
        case .error:
            // X eyes
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Text("×").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                    Text("×").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                }
                Text("︵").font(.system(size: 8)).foregroundColor(.white)
            }
        case .celebrate:
            // Happy squint eyes + smile
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text("^").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                    Text("^").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                }
                Text("◡").font(.system(size: 8)).foregroundColor(.white)
            }
        case .attention:
            // Wide alert eyes
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Circle().fill(.white).frame(width: 5, height: 5)
                    Circle().fill(.white).frame(width: 5, height: 5)
                }
                Text("!").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
            }
        case .typing:
            // Focused eyes + determined mouth
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Capsule().fill(.white).frame(width: 5, height: 3)
                    Capsule().fill(.white).frame(width: 5, height: 3)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 5, height: 2)
            }
        case .searching:
            // One eye bigger (magnifying glass look) + curious mouth
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 3, height: 3)
                    Circle().fill(.white).frame(width: 6, height: 6)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1).frame(width: 8, height: 8))
                }
                Capsule()
                    .fill(.white)
                    .frame(width: 4, height: 2.5)
            }
        default:
            // Normal eyes + smile
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                    Circle().fill(.white).frame(width: 4, height: 4)
                }
                // Smile arc ◡
                Circle()
                    .trim(from: 0.05, to: 0.45)
                    .stroke(.white, lineWidth: 1.5)
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Background Effects

    @ViewBuilder
    private var backgroundEffect: some View {
        switch state {
        case .thinking:
            // No background effect — just the body tilts
            EmptyView()

        case .searching:
            // Radar sweep arc
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color(red: 0.3, green: 0.3, blue: 0.85).opacity(0.4), lineWidth: 2)
                .frame(width: 55, height: 55)
                .rotationEffect(.degrees(Double(frame) * 90))

        case .building:
            // Rotating gear segments
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.9, green: 0.4, blue: 0.2).opacity(0.4))
                    .frame(width: 3, height: 8)
                    .offset(y: -28)
                    .rotationEffect(.degrees(Double(i) * 60 + Double(frame) * 15))
            }

        case .installing:
            // Progress ring
            Circle()
                .trim(from: 0, to: progressAmount)
                .stroke(Color(red: 0.6, green: 0.35, blue: 0.9).opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))

        case .subAgent:
            // Orbiting mini clones
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.3, green: 0.85, blue: 0.7).opacity(0.6))
                    .frame(width: 8, height: 8)
                    .overlay(
                        HStack(spacing: 2) {
                            Circle().fill(.white).frame(width: 1.5, height: 1.5)
                            Circle().fill(.white).frame(width: 1.5, height: 1.5)
                        }
                    )
                    .offset(x: subAgentX(index: i), y: subAgentY(index: i))
            }

        case .testing:
            // Scanning line
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.1, green: 0.8, blue: 0.75).opacity(0.5))
                .frame(width: 50, height: 2)
                .offset(y: scanLineY)

        case .sleeping:
            // Zzz particles floating up
            ForEach(0..<2, id: \.self) { i in
                Text("z")
                    .font(.system(size: CGFloat(6 + i * 2), weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(zzzOpacity(index: i)))
                    .offset(x: CGFloat(10 + i * 8), y: zzzOffsetY(index: i))
            }

        case .attention:
            // Pulsing ring beacon
            Circle()
                .stroke(Color.red.opacity(attentionRingOpacity), lineWidth: 2)
                .frame(width: attentionRingSize, height: attentionRingSize)

        default:
            EmptyView()
        }
    }

    // MARK: - Foreground Effects

    @ViewBuilder
    private var foregroundEffect: some View {
        switch state {
        case .typing:
            // Keystroke ripples
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(rippleOpacity(index: i)), lineWidth: 1)
                    .frame(width: rippleSize(index: i), height: rippleSize(index: i))
                    .offset(y: 5)
            }

        case .celebrate:
            // Firework particles
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(celebrateColor(index: i))
                    .frame(width: 4, height: 4)
                    .offset(x: celebrateX(index: i), y: celebrateY(index: i))
                    .opacity(celebrateOpacity)
            }

        case .error:
            // Shake crack lines
            if frame % 3 == 0 {
                Path { path in
                    path.move(to: CGPoint(x: 35, y: 30))
                    path.addLine(to: CGPoint(x: 38, y: 35))
                    path.addLine(to: CGPoint(x: 36, y: 40))
                    path.addLine(to: CGPoint(x: 39, y: 45))
                }
                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                .offset(x: 5, y: -10)
            }

        case .idle:
            EmptyView()

        default:
            EmptyView()
        }
    }

    // MARK: - Body Properties

    private var bodySize: CGFloat {
        switch state {
        case .sleeping:
            // Breathing effect
            return 40 + sinVal(Double(frame) * .pi / 2) * 2
        case .attention:
            return 40 + (frame % 2 == 0 ? 2 : 0)
        default:
            return 40
        }
    }

    private var bodyScale: CGFloat {
        switch state {
        case .celebrate:
            return 1.0 + sinVal(Double(frame) * .pi / 4) * 0.1
        case .error:
            return 1.0
        default:
            return 1.0
        }
    }

    private var bodyOffsetY: CGFloat {
        switch state {
        case .celebrate:
            // Bouncing
            return -abs(sinVal(Double(frame) * .pi / 4)) * 8
        case .error:
            return 0
        default:
            return 0
        }
    }

    private var bodyRotation: Angle {
        switch state {
        case .error:
            // Shake left-right
            let shake = frame % 3
            return .degrees(shake == 0 ? -5 : shake == 1 ? 5 : 0)
        case .thinking:
            // Slight tilt
            return .degrees(Double(sinVal(Double(frame) * .pi / 3) * 3))
        default:
            return .degrees(0)
        }
    }

    private var shadowColor: Color {
        if state.isUrgent {
            return .red.opacity(0.6)
        }
        return colorForState.opacity(0.3)
    }

    private var shadowRadius: CGFloat {
        switch state {
        case .attention:
            return CGFloat(6 + (frame % 2) * 4)
        case .celebrate:
            return 10
        default:
            return 6
        }
    }

    // MARK: - Animation Calculations

    private func orbitX(index: Int) -> CGFloat {
        let angle = Double(frame) * .pi / 3 + Double(index) * 2.094
        return cosVal(angle) * 28
    }

    private func orbitY(index: Int) -> CGFloat {
        let angle = Double(frame) * .pi / 3 + Double(index) * 2.094
        return sinVal(angle) * 28
    }

    private func subAgentX(index: Int) -> CGFloat {
        let angle = Double(frame) * .pi / 2 + Double(index) * 2.094
        return cosVal(angle) * 30
    }

    private func subAgentY(index: Int) -> CGFloat {
        let angle = Double(frame) * .pi / 2 + Double(index) * 2.094
        return sinVal(angle) * 30
    }

    private var scanLineY: CGFloat {
        let progress = Double(frame) / 4.0
        return -20 + CGFloat(progress) * 10
    }

    private func zzzOffsetY(index: Int) -> CGFloat {
        let base: CGFloat = -20 - CGFloat(index) * 10
        let float = sinVal(Double(frame + index) * .pi / 2) * 3
        return base + float
    }

    private func zzzOpacity(index: Int) -> Double {
        let phase = Double((frame + index) % 4) / 4.0
        return 0.3 + phase * 0.5
    }

    private var progressAmount: CGFloat {
        CGFloat(frame) / CGFloat(max(1, PetState.installing.frameCount))
    }

    private func rippleOpacity(index: Int) -> Double {
        let phase = Double((frame + index * 2) % 4) / 4.0
        return max(0, 0.6 - phase)
    }

    private func rippleSize(index: Int) -> CGFloat {
        let phase = Double((frame + index * 2) % 4) / 4.0
        return 30 + CGFloat(phase) * 25
    }

    private func celebrateX(index: Int) -> CGFloat {
        let angle = Double(index) * .pi / 3
        let radius = Double(frame) * 4.0
        return cosVal(angle) * CGFloat(radius)
    }

    private func celebrateY(index: Int) -> CGFloat {
        let angle = Double(index) * .pi / 3
        let radius = Double(frame) * 4.0
        return sinVal(angle) * CGFloat(radius)
    }

    private var celebrateOpacity: Double {
        max(0, 1.0 - Double(frame) / 8.0)
    }

    private func celebrateColor(index: Int) -> Color {
        let colors: [Color] = [.yellow, .orange, .pink, .cyan, .green, .purple]
        return colors[index % colors.count]
    }

    private var attentionRingOpacity: Double {
        let phase = Double(frame % 12) / 12.0
        // Never fully disappear — oscillate between 0.4 and 0.9
        return 0.4 + (1.0 - phase) * 0.5
    }

    private var attentionRingSize: CGFloat {
        let phase = Double(frame % 12) / 12.0
        return 45 + CGFloat(phase) * 15
    }

    // MARK: - Color

    private var colorForState: Color {
        switch state {
        case .sleeping: return Color(red: 0.55, green: 0.55, blue: 0.6)   // 冷灰
        case .idle: return Color(red: 0.3, green: 0.5, blue: 0.9)          // 天蓝
        case .thinking: return Color(red: 0.95, green: 0.65, blue: 0.15)   // 琥珀橘黄
        case .typing: return Color(red: 0.2, green: 0.8, blue: 0.4)        // 翠绿
        case .building: return Color(red: 0.9, green: 0.4, blue: 0.2)      // 珊瑚橙红
        case .installing: return Color(red: 0.6, green: 0.35, blue: 0.9)   // 紫罗兰
        case .testing: return Color(red: 0.1, green: 0.8, blue: 0.75)      // 青碧
        case .error: return Color(red: 0.9, green: 0.2, blue: 0.25)        // 正红
        case .celebrate: return Color(red: 1.0, green: 0.85, blue: 0.1)    // 明亮金黄
        case .attention: return Color(red: 0.95, green: 0.2, blue: 0.3)    // 警示红
        case .searching: return Color(red: 0.3, green: 0.3, blue: 0.85)    // 靛蓝
        case .subAgent: return Color(red: 0.3, green: 0.85, blue: 0.7)     // 薄荷绿
        }
    }
}
