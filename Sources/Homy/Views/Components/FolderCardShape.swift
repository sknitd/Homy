import SwiftUI

/// A folder silhouette: a rounded rectangle whose left part rises into a tab,
/// joined to the lower top edge with a smooth bezier "shoulder".
struct FolderCardShape: Shape {
    /// Fraction of the width taken by the raised tab.
    var tabWidthRatio: CGFloat = 0.4
    /// How far the tab rises above the main body.
    var tabHeight: CGFloat = 26
    var cornerRadius: CGFloat = 18
    /// Horizontal length of the curve between the tab and the body.
    var shoulder: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.height / 4, rect.width / 4)
        let tabEnd = rect.minX + rect.width * tabWidthRatio
        let bodyTop = rect.minY + tabHeight
        let s = min(shoulder, rect.width * 0.2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        // Top-left corner of the tab.
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + r, y: rect.minY),
            radius: r
        )
        // Tab top edge, then the bezier shoulder down to the body.
        path.addLine(to: CGPoint(x: tabEnd - s / 2, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: tabEnd + s / 2, y: bodyTop),
            control1: CGPoint(x: tabEnd, y: rect.minY),
            control2: CGPoint(x: tabEnd, y: bodyTop)
        )
        // Body top edge and top-right corner.
        path.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: bodyTop),
            tangent2End: CGPoint(x: rect.maxX, y: bodyTop + r),
            radius: r
        )
        // Right edge, bottom corners, left edge.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY),
            radius: r
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r),
            radius: r
        )
        path.closeSubpath()
        return path
    }
}
