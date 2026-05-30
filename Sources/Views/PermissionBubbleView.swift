import SwiftUI

/// Permission approval bubble that appears above the pet
struct PermissionBubbleView: View {
    let permission: PermissionRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            // Arrow pointing down
            Triangle()
                .fill(Color(.windowBackgroundColor))
                .frame(width: 12, height: 6)
                .rotationEffect(.degrees(180))
                .offset(y: 6)

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Permission Request")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                }

                // Tool name
                Text(permission.tool)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Description
                Text(permission.description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Buttons
                HStack(spacing: 8) {
                    Button(action: onDeny) {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                            Text("Deny")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onApprove) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                            Text("Allow")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            )
        }
        .frame(width: 180)
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
