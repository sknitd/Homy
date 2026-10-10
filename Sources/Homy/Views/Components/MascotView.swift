import SwiftUI

/// Homy's mascot: a glossy blue folder holding a fluffy smiling cloud.
/// Drawn entirely with vectors in a 1024 x 1024 design space (same geometry as
/// scripts/generate_icon.py, which renders the app icon).
struct MascotView: View {
    /// Draws the rounded app-icon tile behind the mascot.
    var showsBackground = false
    /// Closes the eyes (used for a little blink animation).
    var eyesClosed = false

    private static let navy = Color(hex: 0x12306B)

    var body: some View {
        Canvas { context, size in
            let content = showsBackground
                ? CGRect(x: 0, y: 0, width: 1024, height: 1024)
                : CGRect(x: 150, y: 230, width: 724, height: 610)
            let scale = min(size.width / content.width, size.height / content.height)
            context.translateBy(
                x: (size.width - content.width * scale) / 2 - content.minX * scale,
                y: (size.height - content.height * scale) / 2 - content.minY * scale
            )
            context.scaleBy(x: scale, y: scale)
            draw(in: &context)
        }
        .aspectRatio(content.width / content.height, contentMode: .fit)
        .accessibilityLabel("Homy mascot")
    }

    private var content: CGSize {
        showsBackground ? CGSize(width: 1024, height: 1024) : CGSize(width: 724, height: 610)
    }

    private func gradient(_ top: UInt32, _ bottom: UInt32, from y0: CGFloat, to y1: CGFloat) -> GraphicsContext.Shading {
        .linearGradient(
            Gradient(colors: [Color(hex: top), Color(hex: bottom)]),
            startPoint: CGPoint(x: 512, y: y0),
            endPoint: CGPoint(x: 512, y: y1)
        )
    }

    private func draw(in context: inout GraphicsContext) {
        if showsBackground {
            let tile = Path(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185, style: .continuous)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.2), radius: 14, y: 10))
                layer.fill(tile, with: gradient(0xF5FAFF, 0xCFE3FF, from: 100, to: 924))
            }
        }

        // Folder back with its tab.
        var back = Path(roundedRect: CGRect(x: 190, y: 330, width: 644, height: 470), cornerRadius: 48, style: .continuous)
        back.addPath(Path(roundedRect: CGRect(x: 190, y: 282, width: 290, height: 98), cornerRadius: 36, style: .continuous))
        back.addRect(CGRect(x: 190, y: 330, width: 70, height: 50))
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0x143C8C, opacity: 0.25), radius: 24, y: 14))
            layer.fill(back, with: gradient(0x2F86F6, 0x1858D0, from: 282, to: 800))
        }

        // Fluffy cloud.
        var cloud = Path()
        for (cx, cy, r) in [(380.0, 470.0, 110.0), (520, 400, 150), (660, 470, 115), (300, 565, 85), (740, 565, 85)] {
            cloud.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        cloud.addRoundedRect(in: CGRect(x: 300, y: 470, width: 440, height: 180), cornerSize: CGSize(width: 70, height: 70))
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0x143C8C, opacity: 0.22), radius: 18, y: 10))
            layer.fill(cloud, with: gradient(0xFFFFFF, 0xE4EEFB, from: 250, to: 650))
        }

        // Face.
        for ex in [450.0, 590.0] {
            if eyesClosed {
                var lid = Path()
                lid.move(to: CGPoint(x: ex - 20, y: 452))
                lid.addQuadCurve(to: CGPoint(x: ex + 20, y: 452), control: CGPoint(x: ex, y: 466))
                context.stroke(lid, with: .color(Self.navy), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: ex - 18, y: 425, width: 36, height: 52)), with: .color(Self.navy))
                context.fill(Path(ellipseIn: CGRect(x: ex - 9, y: 433, width: 12, height: 14)), with: .color(.white))
            }
        }
        var smile = Path()
        smile.move(to: CGPoint(x: 486, y: 494))
        smile.addQuadCurve(to: CGPoint(x: 554, y: 494), control: CGPoint(x: 520, y: 532))
        context.stroke(smile, with: .color(Self.navy), style: StrokeStyle(lineWidth: 12, lineCap: .round))

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            for bx in [395.0, 645.0] {
                layer.fill(Path(ellipseIn: CGRect(x: bx - 30, y: 488, width: 60, height: 26)), with: .color(Color(hex: 0xFF7896, opacity: 0.47)))
            }
        }

        // Folder front panel + gloss.
        let front = Path(roundedRect: CGRect(x: 170, y: 560, width: 684, height: 262), cornerRadius: 50, style: .continuous)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0x143C8C, opacity: 0.2), radius: 16, y: -6))
            layer.fill(front, with: gradient(0x62B4FF, 0x1F6FEB, from: 560, to: 822))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.fill(
                Path(roundedRect: CGRect(x: 196, y: 576, width: 632, height: 64), cornerRadius: 30),
                with: .color(.white.opacity(0.43))
            )
        }
    }
}

/// The app name set in a heavy rounded face, with the mascot.
struct HomyWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: size * 0.3) {
            MascotView()
                .frame(width: size * 1.5, height: size * 1.3)
            Text("Homy")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Theme.navy)
        }
    }
}
