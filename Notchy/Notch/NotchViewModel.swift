//
//  NotchViewModel.swift
//  Notchy
//
//  Holds the visual state of the notch panel: reveal progress,
//  horizontal page index, panel geometry, and open/closed state.
//

import AppKit
import Combine

@MainActor
final class NotchViewModel: ObservableObject {
    /// 0 = closed, 1 = fully open. Animatable via SwiftUI.
    @Published var reveal: CGFloat = 0
    @Published var isOpen = false

    /// Horizontal paging: 0 = Studio, 1 = Shelf & Stats, 2 = AI & 2FA
    @Published var selectedPage: Int = 0

    /// File dragging over the notch / shelf
    @Published var isDragOverNotch: Bool = false

    /// Indicates whether a background live activity is active (media playing or timer running)
    @Published var hasActiveLiveActivity: Bool = false

    let openWidth: CGFloat
    let contentHeight: CGFloat
    /// Height of the "neck" strip that sits inside the physical notch (0 on non-notch Macs).
    let topInset: CGFloat
    /// Visible silhouette when closed (the physical notch, or a floating pill).
    let neckSize: CGSize
    let neckOrigin: CGPoint
    let hasNotch: Bool

    init(screen: NSScreen) {
        let geometry = screen.notchGeometry
        let openWidth = min(screen.frame.width - 48, 660)
        self.openWidth = openWidth
        self.contentHeight = 220
        self.hasNotch = geometry.hasNotch
        self.topInset = geometry.hasNotch ? geometry.size.height : 0

        if geometry.hasNotch {
            neckSize = geometry.size
            neckOrigin = CGPoint(x: openWidth / 2 - geometry.size.width / 2, y: 0)
        } else {
            // Floating "dynamic island" pill for Macs without a notch.
            neckSize = CGSize(width: 210, height: 32)
            neckOrigin = CGPoint(x: openWidth / 2 - 105, y: 6)
        }
    }

    /// Hot rect of the closed notch, in the panel's own coordinate space.
    var neckRect: CGRect {
        CGRect(origin: neckOrigin, size: neckSize)
    }

    /// Rect covering everything interactive when open, in panel coordinates.
    var expandedRect: CGRect {
        CGRect(x: 0, y: 0, width: openWidth, height: topInset + contentHeight)
    }

    // MARK: - Horizontal Paging Navigation
    func advancePage() {
        let maxPage = max(0, PageLayoutManager.shared.activePages.count - 1)
        if selectedPage < maxPage {
            selectedPage += 1
        }
    }

    func rewindPage() {
        if selectedPage > 0 {
            selectedPage -= 1
        }
    }

    func selectPage(_ page: Int) {
        let maxPage = max(0, PageLayoutManager.shared.activePages.count - 1)
        guard page >= 0, page <= maxPage else { return }
        selectedPage = page
    }
}
