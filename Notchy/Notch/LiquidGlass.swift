//
//  LiquidGlass.swift
//  Notchy
//
//  Official Apple Liquid Glass design system adoption.
//  Ref: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
//  Provides hardware-concentric glass pods, specular rim gradients,
//  interaction-responsive controls, and accessibility compliance.
//

import SwiftUI
import AppKit

// MARK: - Native macOS Vibrancy VisualEffectView

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Liquid Glass Pod Modifier

struct LiquidGlassPodModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 16
    var isHovered: Bool = false
    var ambientTint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(white: 0.12))
                } else {
                    ZStack {
                        // Base optical glass material - semi-transparent so backdrop blur shows through
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.55))

                        // Subtle dark tint for card depth & contrast
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.20))

                        // Ambient chromatic refraction if provided (e.g. from album art)
                        if let tint = ambientTint {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [tint.opacity(0.22), tint.opacity(0.06), Color.clear],
                                        center: .topLeading,
                                        startRadius: 10,
                                        endRadius: 180
                                    )
                                )
                        }

                        // Subtle surface sheen
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.10 : 0.05),
                                        Color.white.opacity(isHovered ? 0.03 : 0.01)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            .overlay {
                // Apple Specular Rim Highlight: light striking the top-leading beveled glass edge
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isHovered ? 0.32 : 0.18), location: 0.0),
                                .init(color: Color.white.opacity(isHovered ? 0.14 : 0.07), location: 0.3),
                                .init(color: Color.white.opacity(0.02), location: 0.8),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies Apple's official Liquid Glass pod styling with concentric squircle curvature
    func liquidGlassPod(
        cornerRadius: CGFloat = 16,
        isHovered: Bool = false,
        ambientTint: Color? = nil
    ) -> some View {
        modifier(LiquidGlassPodModifier(
            cornerRadius: cornerRadius,
            isHovered: isHovered,
            ambientTint: ambientTint
        ))
    }

    /// Applies a unified grouped Liquid Glass capsule styling (for toolbars and segmented switchers)
    func liquidGlassCapsule(
        isHovered: Bool = false,
        ambientTint: Color? = nil
    ) -> some View {
        modifier(LiquidGlassPodModifier(
            cornerRadius: 100,
            isHovered: isHovered,
            ambientTint: ambientTint
        ))
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 10
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isProminent ? Color.accentColor : Color(white: 0.18))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(isProminent ? AnyShapeStyle(Color.accentColor.opacity(configuration.isPressed ? 0.9 : 0.75)) : AnyShapeStyle(.ultraThinMaterial.opacity(0.85)))
                        
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0.06))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.40 : 0.22),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
