import SwiftUI

/// The Ibanga mark: a speech bubble with a keyhole cut through it — a conversation that stays locked.
/// The same geometry renders the app icon, so the in-app mark and the icon never drift apart.
struct IbangaLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * side, y: origin.y + y * side)
        }

        let body = Path(
            roundedRect: CGRect(origin: point(0.06, 0.08), size: CGSize(width: 0.88 * side, height: 0.66 * side)),
            cornerRadius: 0.24 * side,
            style: .continuous
        )

        var tail = Path()
        tail.move(to: point(0.20, 0.58))
        tail.addLine(to: point(0.42, 0.70))
        tail.addQuadCurve(to: point(0.13, 0.92), control: point(0.27, 0.86))
        tail.addQuadCurve(to: point(0.20, 0.58), control: point(0.21, 0.78))
        tail.closeSubpath()

        let bow = Path(ellipseIn: CGRect(
            x: origin.x + (0.5 - 0.105) * side,
            y: origin.y + (0.36 - 0.105) * side,
            width: 0.21 * side,
            height: 0.21 * side
        ))

        var stem = Path()
        stem.move(to: point(0.458, 0.40))
        stem.addLine(to: point(0.542, 0.40))
        stem.addLine(to: point(0.572, 0.585))
        stem.addQuadCurve(to: point(0.552, 0.61), control: point(0.575, 0.61))
        stem.addLine(to: point(0.448, 0.61))
        stem.addQuadCurve(to: point(0.428, 0.585), control: point(0.425, 0.61))
        stem.closeSubpath()

        return body.union(tail).subtracting(bow.union(stem))
    }
}

/// The mark on its brand tile, used for launch and onboarding.
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(IbangaBrand.tileGradient)
            .frame(width: size, height: size)
            .overlay {
                IbangaLogoShape()
                    .fill(.white)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
            .accessibilityHidden(true)
    }
}

enum IbangaBrand {
    static let tileGradient = LinearGradient(
        colors: [Color(red: 0x2A / 255, green: 0x75 / 255, blue: 0x64 / 255), Color(red: 0x16 / 255, green: 0x44 / 255, blue: 0x3A / 255)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let markGradient = LinearGradient(
        colors: [Color(red: 0x84 / 255, green: 0xDC / 255, blue: 0xC3 / 255), Color(red: 0x4F / 255, green: 0xAF / 255, blue: 0x94 / 255)],
        startPoint: .top,
        endPoint: .bottom
    )
}

#Preview {
    HStack(spacing: 24) {
        BrandMark(size: 96)
        BrandMark(size: 56)
    }
    .padding()
}
