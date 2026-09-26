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

// MARK: - Official Apple Liquid Glass Engine (NSGlassEffectView)

public struct AppleLiquidGlassSurface: NSViewRepresentable {
    public var cornerRadius: CGFloat
    public var variant: Int = 11

    public init(cornerRadius: CGFloat = 38, variant: Int = 11) {
        self.cornerRadius = cornerRadius
        self.variant = variant
    }

    public func makeNSView(context: Context) -> NSView {
        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let glass = glassType.init(frame: .zero)
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(cornerRadius, forKey: "cornerRadius")

            let selVariant = NSSelectorFromString("set_variant:")
            if glass.responds(to: selVariant) {
                let imp = class_getMethodImplementation(object_getClass(glass), selVariant)
                typealias VariantFn = @convention(c) (AnyObject, Selector, Int) -> Void
                let fn = unsafeBitCast(imp, to: VariantFn.self)
                fn(glass, selVariant, variant)
            }

            let selLensing = NSSelectorFromString("set_contentLensing:")
            if glass.responds(to: selLensing) {
                let imp = class_getMethodImplementation(object_getClass(glass), selLensing)
                typealias BoolFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                let fn = unsafeBitCast(imp, to: BoolFn.self)
                fn(glass, selLensing, true)
            }

            container.addSubview(glass)
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                glass.topAnchor.constraint(equalTo: container.topAnchor),
                glass.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return container
        }

        // Fallback for earlier macOS
        let fallback = NSVisualEffectView()
        fallback.material = .hudWindow
        fallback.blendingMode = .behindWindow
        fallback.state = .active
        return fallback
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let glass = nsView.subviews.first, NSStringFromClass(type(of: glass)).contains("Glass") {
            glass.setValue(cornerRadius, forKey: "cornerRadius")
        }
    }
}

// MARK: - Module Corner Radii

public struct ModuleCornerRadii: Equatable, Sendable {
    public var topLeading: CGFloat
    public var bottomLeading: CGFloat
    public var bottomTrailing: CGFloat
    public var topTrailing: CGFloat

    public init(
        topLeading: CGFloat = 16,
        bottomLeading: CGFloat = 16,
        bottomTrailing: CGFloat = 16,
        topTrailing: CGFloat = 16
    ) {
        self.topLeading = topLeading
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
        self.topTrailing = topTrailing
    }

    public static let standard = ModuleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 16, topTrailing: 16)

    public var asShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing,
            style: .continuous
        )
    }
}

private struct ModuleCornerRadiiKey: EnvironmentKey {
    static let defaultValue: ModuleCornerRadii = .standard
}

extension EnvironmentValues {
    public var moduleCornerRadii: ModuleCornerRadii {
        get { self[ModuleCornerRadiiKey.self] }
        set { self[ModuleCornerRadiiKey.self] = newValue }
    }
}

// MARK: - Liquid Glass Pod Modifier

struct LiquidGlassPodModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.moduleCornerRadii) private var envRadii
    @AppStorage("cardGlassOpacity") private var cardGlassOpacity = 0.85
    @AppStorage("glassMaterialStyle") private var glassMaterialStyle = "opaque"
    var cornerRadius: CGFloat? = nil
    var isHovered: Bool = false
    var ambientTint: Color? = nil

    private var effectiveShape: UnevenRoundedRectangle {
        if let cr = cornerRadius, cr != 16 {
            return UnevenRoundedRectangle(
                topLeadingRadius: cr,
                bottomLeadingRadius: cr,
                bottomTrailingRadius: cr,
                topTrailingRadius: cr,
                style: .continuous
            )
        }
        return envRadii.asShape
    }

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency || glassMaterialStyle == "opaque" {
                    effectiveShape
                        .fill(Color(white: 0.14))
                } else {
                    ZStack {
                        // Base optical glass material - user controlled translucency
                        effectiveShape
                            .fill(.ultraThinMaterial.opacity(cardGlassOpacity))

                        // Subtle dark tint for card depth & contrast
                        effectiveShape
                            .fill(Color.black.opacity(0.18))

                        // Ambient chromatic refraction if provided (e.g. from album art)
                        if let tint = ambientTint {
                            effectiveShape
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
                        effectiveShape
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
                effectiveShape
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
            .clipShape(effectiveShape)
    }
}

// MARK: - View Extension

extension View {
    /// Applies Apple's official Liquid Glass pod styling with concentric squircle curvature
    func liquidGlassPod(
        cornerRadius: CGFloat? = nil,
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
