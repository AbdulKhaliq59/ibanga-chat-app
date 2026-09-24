import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders the app icon variants from `IbangaLogoShape`, the same geometry the app draws.
@main
struct AppIconRenderer {
    @MainActor
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for variant in IconVariant.allCases {
            let renderer = ImageRenderer(content: IconView(variant: variant))
            renderer.scale = 1
            renderer.isOpaque = variant == .light
            guard let image = renderer.cgImage else { throw RenderError.failed(variant.filename) }
            try write(image, to: directory.appending(path: variant.filename))
            print("✓ \(variant.filename)")
        }
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError.failed(url.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.failed(url.lastPathComponent) }
    }
}

enum RenderError: Error {
    case failed(String)
}

enum IconVariant: CaseIterable {
    case light, dark, tinted

    var filename: String {
        switch self {
        case .light: "AppIcon.png"
        case .dark: "AppIcon-Dark.png"
        case .tinted: "AppIcon-Tinted.png"
        }
    }
}

struct IconView: View {
    let variant: IconVariant

    var body: some View {
        ZStack {
            if variant == .light {
                IbangaBrand.tileGradient
                RadialGradient(colors: [.white.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 700)
            }
            logo
                .frame(width: 600, height: 600)
                .offset(y: 8)
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder
    private var logo: some View {
        switch variant {
        case .light: IbangaLogoShape().fill(.white)
        case .dark: IbangaLogoShape().fill(IbangaBrand.markGradient)
        case .tinted: IbangaLogoShape().fill(.white)
        }
    }
}
