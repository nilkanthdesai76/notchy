//
//  NotchShape.swift
//  Notchy
//
//  Continuous squircle notch silhouette matching Apple hardware notch aesthetics.
//  Features top concave inverted flare curves ("ears") blending into the display bezel
//  and bottom continuous curvature squircles.
//

import SwiftUI

struct NotchSilhouetteShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var hasInvertedEars: Bool = true

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if hasInvertedEars && topRadius > 0.5 {
            let tr = min(topRadius, rect.height / 3, rect.width / 4)
            let br = min(bottomRadius, rect.height - tr, rect.width / 2)

            // Top-left start at display bezel edge
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))

            // Flared concave top-left ear curving down into notch body
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                control: CGPoint(x: rect.minX + tr, y: rect.minY)
            )

            // Left vertical side
            path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))

            // Bottom-left continuous rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                control: CGPoint(x: rect.minX + tr, y: rect.maxY)
            )

            // Bottom horizontal line
            path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))

            // Bottom-right continuous rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
            )

            // Right vertical side
            path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))

            // Flared concave top-right ear curving up into display bezel
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.maxX - tr, y: rect.minY)
            )

            // Top edge close
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        } else {
            // Standard rounded pill for non-notch compact closed pill,
            // or flush top edge with rounded bottom corners when open from top bezel.
            let br = min(bottomRadius, rect.height, rect.width / 2)
            let tr = min(topRadius, rect.height / 2, rect.width / 2)

            if tr > 0.5 {
                // Closed floating/menu-bar pill
                path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                    control: CGPoint(x: rect.maxX, y: rect.minY)
                )
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - br),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + tr, y: rect.minY),
                    control: CGPoint(x: rect.minX, y: rect.minY)
                )
                path.closeSubpath()
            } else {
                // Open panel: top edge is flush with the top screen bezel, bottom corners are squircles
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - br),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.closeSubpath()
            }
        }

        return path
    }
}
