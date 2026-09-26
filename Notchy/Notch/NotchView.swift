//
//  NotchView.swift
//  Notchy
//
//  Root SwiftUI view of the notch panel with continuous squircle corners,
//  stealth closed state, live activity peeking, and custom horizontal carousel.
//

import Combine
import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var clipboard: ClipboardManager
    @EnvironmentObject private var camera: CameraManager
    @ObservedObject private var timer = TimerManager.shared
    @ObservedObject private var shelf = ShelfManager.shared
    @ObservedObject private var stats = SystemStatsManager.shared

    @AppStorage("liveActivityMediaEnabled") private var liveActivityMediaEnabled = true
    @AppStorage("liveActivityTimerEnabled") private var liveActivityTimerEnabled = true
    @AppStorage("liveActivityShelfEnabled") private var liveActivityShelfEnabled = true
    @AppStorage("liveActivityHideInFullscreen") private var liveActivityHideInFullscreen = true
    @AppStorage("glassOpacity") private var glassOpacity = 0.58
    @AppStorage("showPanelShadow") private var showPanelShadow = false
    @AppStorage("glassMaterialStyle") private var glassMaterialStyle = "liquid"
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showBottomGlow") private var showBottomGlow = false

    @ObservedObject private var fullscreen = FullscreenDetector.shared

    private let openAnimation = Animation.spring(response: 0.34, dampingFraction: 0.8)

    private var isMediaLiveActive: Bool {
        liveActivityMediaEnabled && media.isPlaying
    }

    private var isTimerLiveActive: Bool {
        liveActivityTimerEnabled && timer.isRunning
    }

    private var isShelfLiveActive: Bool {
        liveActivityShelfEnabled && (viewModel.isDragOverNotch || shelf.isTargeted)
    }

    private var isLiveActivityActive: Bool {
        if liveActivityHideInFullscreen && fullscreen.isFullscreen {
            return false
        }
        return isMediaLiveActive || isTimerLiveActive || isShelfLiveActive
    }

    // MARK: - Dynamic Island Multi-Activity Slotting
    private enum LeadingSlot {
        case mediaArtwork
        case timerIcon
        case shelfIcon
    }

    private enum TrailingSlot {
        case timerCountdown
        case mediaVisualizer
        case shelfAction
    }

    private var leadingSlot: LeadingSlot? {
        guard isLiveActivityActive else { return nil }
        if isShelfLiveActive {
            return isMediaLiveActive ? .mediaArtwork : (isTimerLiveActive ? .timerIcon : .shelfIcon)
        }
        if isMediaLiveActive {
            return .mediaArtwork
        }
        if isTimerLiveActive {
            return .timerIcon
        }
        return nil
    }

    private var trailingSlot: TrailingSlot? {
        guard isLiveActivityActive else { return nil }
        if isShelfLiveActive {
            return .shelfAction
        }
        // If both Media and Timer are running, Timer countdown takes trailing slot while Media takes leading slot!
        if isTimerLiveActive {
            return .timerCountdown
        }
        if isMediaLiveActive {
            return .mediaVisualizer
        }
        return nil
    }

    var body: some View {
        let neckHeight: CGFloat = viewModel.hasNotch ? viewModel.topInset : 32
        let topPad: CGFloat = viewModel.hasNotch ? 0 : 6
        let silhouetteHeight = topPad + neckHeight + viewModel.contentHeight * viewModel.reveal

        // Dynamic asymmetric ear widths tailored to content
        let leadingEarWidth: CGFloat = {
            guard isLiveActivityActive else { return 0 }
            if !viewModel.hasNotch { return 26 }
            switch leadingSlot {
            case .mediaArtwork: return 42
            case .timerIcon: return 40
            case .shelfIcon: return 40
            case nil: return 0
            }
        }()

        let trailingEarWidth: CGFloat = {
            guard isLiveActivityActive else { return 0 }
            if !viewModel.hasNotch { return trailingSlot == .timerCountdown ? 58 : 32 }
            switch trailingSlot {
            case .timerCountdown: return 68
            case .mediaVisualizer: return 44
            case .shelfAction: return 42
            case nil: return 0
            }
        }()

        let closedWidth: CGFloat = {
            if isLiveActivityActive {
                if viewModel.hasNotch {
                    return leadingEarWidth + viewModel.neckSize.width + trailingEarWidth
                } else {
                    return leadingEarWidth + 14 + trailingEarWidth
                }
            } else {
                return viewModel.hasNotch ? viewModel.neckSize.width : 0
            }
        }()
        let silhouetteWidth = closedWidth + (viewModel.openWidth - closedWidth) * viewModel.reveal

        // When asymmetric, closed silhouette center shifts so the center spacer remains exactly on the hardware notch
        let closedCenterX: CGFloat = {
            if viewModel.hasNotch && isLiveActivityActive {
                return viewModel.openWidth / 2 + (trailingEarWidth - leadingEarWidth) / 2
            } else {
                return viewModel.openWidth / 2
            }
        }()
        let silhouetteCenterX = closedCenterX + (viewModel.openWidth / 2 - closedCenterX) * viewModel.reveal

        // Flared ears connecting to top bezel on notch Macs; continuous squircles on bottom
        // When closed: 14pt bottom radius matching physical notch curvature. When open: 38pt sweeping squircle.
        let topRadius: CGFloat = viewModel.isOpen ? 12 : (viewModel.hasNotch ? 8 : 14)
        let bottomRadius: CGFloat = viewModel.isOpen ? 38 : (viewModel.hasNotch ? 14 : 14)
        let shape = NotchSilhouetteShape(
            topRadius: topRadius,
            bottomRadius: bottomRadius,
            hasInvertedEars: viewModel.hasNotch
        )

        ZStack(alignment: .top) {
            // Main notch silhouette background + expanded content
            VStack(spacing: 0) {
                Spacer().frame(height: topPad + neckHeight)
                if viewModel.reveal > 0.02 {
                    NotchExpandedContent(viewModel: viewModel)
                        .frame(width: viewModel.openWidth, height: viewModel.contentHeight)
                        .opacity(Double(min(viewModel.reveal * 1.8, 1)))
                        .offset(y: (1 - viewModel.reveal) * 8)
                }
            }
            .frame(width: silhouetteWidth, height: silhouetteHeight, alignment: .top)
            .background(
                ZStack {
                    if !viewModel.isOpen {
                        // Closed state: pure seamless hardware black matching display bezel
                        Color.black
                    } else if glassMaterialStyle == "opaque" {
                        Color.black
                    } else {
                        // 1. Official Apple Liquid Glass Engine (NSGlassEffectView with variant 11 & content lensing)
                        AppleLiquidGlassSurface(cornerRadius: 38, variant: 11)

                        // 2. Liquid Glass Translucent Dark Graphite Tint
                        // Respects user glassOpacity preference
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.88), location: 0.0), // Deep anchoring black under bezel
                                .init(color: Color(white: 0.08).opacity(glassOpacity), location: 0.18),
                                .init(color: Color(white: 0.03).opacity(max(glassOpacity - 0.12, 0.08)), location: 0.85),
                                .init(color: Color(white: 0.05).opacity(max(glassOpacity - 0.06, 0.10)), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // 3. Specular Glass Depth Sheen & Caustic Focus (Apple Liquid Glass)
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18 * (glassOpacity > 0.3 ? 1.0 : 0.5)), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.18),
                                .init(color: Color.clear, location: 0.55),
                                .init(color: Color.white.opacity(0.04), location: 0.85),
                                .init(color: showBottomGlow ? Color(red: 1.0, green: 0.88, blue: 0.75).opacity(0.18) : Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            )
            .clipShape(shape)
            .shadow(
                color: (showPanelShadow && viewModel.isOpen) ? Color.black.opacity(0.35) : Color.clear,
                radius: 20,
                x: 0,
                y: 8
            )
            .position(x: silhouetteCenterX, y: silhouetteHeight / 2)
            .opacity((!viewModel.isOpen && !isLiveActivityActive && !viewModel.hasNotch) ? 0 : 1)

            // Closed-state peek: Multi-activity Dynamic Island flanking wings
            if !viewModel.isOpen && isLiveActivityActive {
                closedFlankingWings(
                    leadingSlot: leadingSlot,
                    trailingSlot: trailingSlot,
                    leadingEarWidth: leadingEarWidth,
                    trailingEarWidth: trailingEarWidth,
                    neckHeight: neckHeight
                )
                .frame(width: closedWidth, height: neckHeight)
                .position(x: closedCenterX, y: topPad + neckHeight / 2)
                .opacity(viewModel.reveal > 0.05 ? 0 : 1)
                .transition(.opacity)
            }
        }
        .frame(width: viewModel.openWidth, height: viewModel.topInset + viewModel.contentHeight + 48)
        .animation(openAnimation, value: viewModel.reveal)
        .animation(openAnimation, value: viewModel.isOpen)
        .animation(.easeInOut(duration: 0.22), value: isLiveActivityActive)
        .animation(.easeInOut(duration: 0.22), value: leadingEarWidth)
        .animation(.easeInOut(duration: 0.22), value: trailingEarWidth)
    }

    // MARK: - Closed State: Flanking Wings (Left & Right of Notch)
    @ViewBuilder
    private func closedFlankingWings(
        leadingSlot: LeadingSlot?,
        trailingSlot: TrailingSlot?,
        leadingEarWidth: CGFloat,
        trailingEarWidth: CGFloat,
        neckHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            // Left Ear (Outboard left of hardware notch)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                switch leadingSlot {
                case .mediaArtwork:
                    if let data = media.state.artwork, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 17, height: 17)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                    }
                case .timerIcon:
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                case .shelfIcon:
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.blue)
                case nil:
                    EmptyView()
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, viewModel.hasNotch ? 14 : 4)
            .padding(.trailing, 6)
            .frame(width: leadingEarWidth, height: neckHeight)

            // Center Spacer (directly under the physical camera cutout)
            if viewModel.hasNotch {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: viewModel.neckSize.width, height: neckHeight)
            } else {
                Spacer(minLength: 8)
            }

            // Right Ear (Outboard right of hardware notch)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                switch trailingSlot {
                case .timerCountdown:
                    Text(timer.timeRemainingString)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .fixedSize()
                case .mediaVisualizer:
                    MediaVisualizerView(isPlaying: true, barCount: 3, color: .green)
                        .frame(width: 14, height: 12)
                case .shelfAction:
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue)
                case nil:
                    EmptyView()
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.trailing, viewModel.hasNotch ? 14 : 4)
            .frame(width: trailingEarWidth, height: neckHeight)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Expanded Panel Content
private struct NotchExpandedContent: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var stats = SystemStatsManager.shared
    @ObservedObject private var layout = PageLayoutManager.shared
    @ObservedObject private var lm = LicenseManager.shared
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true

    var body: some View {
        let pageWidth = viewModel.openWidth - 48
        let activePages = layout.activePages

        ZStack {
            VStack(spacing: 8) {
                // Header: Date/Time (left) + [Battery] [ < > ] [Settings] (right)
                HStack(alignment: .center, spacing: 8) {
                    // Clock / Date
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text(Date.now.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 90, alignment: .leading)

                    Spacer()

                    // Battery indicator (toggleable from Settings)
                    if showBatteryIndicator {
                        HStack(spacing: 3.5) {
                            Image(systemName: stats.isCharging ? "battery.100.bolt" : "battery.75")
                                .font(.system(size: 9))
                                .foregroundStyle(stats.batteryPercentage <= 20 ? .red : (stats.isCharging ? .green : .white.opacity(0.75)))
                            Text("\(stats.batteryPercentage)%")
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                    }

                    // Small Next / Back arrow buttons beside settings
                    if activePages.count > 1 {
                        HStack(spacing: 1.5) {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    viewModel.rewindPage()
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(viewModel.selectedPage > 0 ? Color.white.opacity(0.85) : Color.white.opacity(0.20))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.selectedPage <= 0)
                            .help("Previous Page (⌘←)")

                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    viewModel.advancePage()
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(viewModel.selectedPage < activePages.count - 1 ? Color.white.opacity(0.85) : Color.white.opacity(0.20))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.selectedPage >= activePages.count - 1)
                            .help("Next Page (⌘→)")
                        }
                        .padding(2)
                        .liquidGlassCapsule()
                    }

                    // Action: Single clean Settings button in top right
                    NotchIconButton(systemName: "gearshape.fill", fontSize: 10.5) {
                        SettingsWindowController.shared.show()
                    }
                    .help("Settings")
                }

                // Dynamic Smooth Horizontal Carousel (omits empty pages)
                if activePages.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No Active Modules")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Button("Customize in Settings") {
                            SettingsWindowController.shared.show()
                        }
                        .controlSize(.small)
                        Spacer()
                    }
                    .frame(width: pageWidth, height: 165)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(activePages) { page in
                            NotchPageView(page: page, width: pageWidth)
                                .frame(width: pageWidth, height: 165)
                                .compositingGroup()
                        }
                    }
                    .frame(width: pageWidth, alignment: .leading)
                    .offset(x: -CGFloat(min(viewModel.selectedPage, max(0, activePages.count - 1))) * pageWidth)
                    .clipped()
                    .animation(.spring(response: 0.36, dampingFraction: 0.82), value: viewModel.selectedPage)
                }

                // Trial banner (only visible during trial)
                TrialBannerView()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(width: viewModel.openWidth, height: viewModel.contentHeight, alignment: .top)

            // License gate overlay (only when trial expired)
            if case .trialExpired = lm.state {
                LicenseGateView()
                    .frame(width: viewModel.openWidth, height: viewModel.contentHeight)
                    .transition(.opacity)
            }
        }
        .frame(width: viewModel.openWidth, height: viewModel.contentHeight, alignment: .top)
    }
}


struct CardSlotCountKey: EnvironmentKey {
    static let defaultValue: Int = 3
}

struct CardWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 190
}

extension EnvironmentValues {
    var cardSlotCount: Int {
        get { self[CardSlotCountKey.self] }
        set { self[CardSlotCountKey.self] = newValue }
    }

    var cardWidth: CGFloat {
        get { self[CardWidthKey.self] }
        set { self[CardWidthKey.self] = newValue }
    }
}

// MARK: - Dedicated Page View with Equatable Layer Caching
private struct NotchPageView: View, Equatable {
    let page: PageConfig
    let width: CGFloat

    static func == (lhs: NotchPageView, rhs: NotchPageView) -> Bool {
        lhs.page == rhs.page && lhs.width == rhs.width
    }

    var body: some View {
        if page.modules.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "plus.square.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Page \(page.id + 1) is empty")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Customize in Settings") {
                    SettingsWindowController.shared.show()
                }
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.cyan)
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.moduleCornerRadii, ModuleCornerRadii(topLeading: 16, bottomLeading: 26, bottomTrailing: 26, topTrailing: 16))
            .liquidGlassPod()
        } else {
            let gap: CGFloat = 8
            let count = page.modules.count
            let available = width - CGFloat(max(0, count - 1)) * gap

            HStack(spacing: gap) {
                ForEach(Array(page.modules.enumerated()), id: \.element.id) { index, module in
                    let itemWidth = moduleWidth(for: module, in: page.modules, available: available)
                    let isFirst = index == 0
                    let isLast = index == count - 1

                    // Concentric squircle curvature matching the notch's 38pt bottomRadius with 12pt padding:
                    // R_inner = 38 - 12 = 26pt for outer bottom corners
                    let radii = ModuleCornerRadii(
                        topLeading: 16,
                        bottomLeading: isFirst ? 26 : 16,
                        bottomTrailing: isLast ? 26 : 16,
                        topTrailing: 16
                    )

                    moduleView(for: module)
                        .id("\(page.id)_\(module.rawValue)")
                        .environment(\.moduleCornerRadii, radii)
                        .environment(\.cardSlotCount, count)
                        .environment(\.cardWidth, itemWidth)
                        .frame(width: itemWidth, height: 165)
                }
            }
            .frame(width: width, height: 165)
        }
    }

    @ViewBuilder
    private func moduleView(for module: NotchyModuleID) -> some View {
        switch module {
        case .media:
            MediaView()
        case .clipboard:
            ClipboardView()
        case .camera:
            CameraView()
        case .shelf:
            ShelfView()
        case .stats:
            StatsAndToolsView()
        case .aiUsage:
            AIUsageView()
        case .otp:
            OTPView()
        case .timer:
            TimerView()
        }
    }

    private func moduleWidth(for module: NotchyModuleID, in modules: [NotchyModuleID], available: CGFloat) -> CGFloat {
        let count = modules.count
        guard count > 1 else { return available }

        let containsCamera = modules.contains(.camera)

        if count == 2 {
            if containsCamera {
                return module == .camera ? available * 0.18 : available * 0.82
            }
            return available * 0.50
        }

        if count == 3 {
            if containsCamera {
                if module == .camera {
                    return available * 0.14
                }
                if modules.contains(.media) && modules.contains(.clipboard) {
                    return module == .media ? available * 0.30 : available * 0.56
                }
                let remainder = available * 0.86
                return remainder * 0.50
            }
            return available / 3.0
        }

        return available / CGFloat(count)
    }
}
