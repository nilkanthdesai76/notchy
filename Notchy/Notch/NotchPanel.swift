//
//  NotchPanel.swift
//  Notchy
//
//  Bordered transparent panel with two-finger trackpad horizontal paging
//  and native file drag & drop destination.
//

import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .mainMenu + 3 // above the menu bar, below Spotlight
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false

        registerForDraggedTypes([.fileURL])
    }
}

/// Hosting view that supports two-finger trackpad horizontal swipe and file dragging.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    weak var viewModel: NotchViewModel?
    private var swipeAccumX: CGFloat = 0
    private var swipeAccumY: CGFloat = 0

    init(rootView: Content, viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @MainActor required dynamic init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Two-Finger Trackpad Horizontal Swipe
    override func scrollWheel(with event: NSEvent) {
        guard let vm = viewModel, vm.isOpen else {
            super.scrollWheel(with: event)
            return
        }

        // Shift+scroll or horizontal trackpad gestures
        if event.modifierFlags.contains(.shift) {
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
            guard abs(delta) > 1.0 else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                if delta < 0 {
                    vm.advancePage()
                } else {
                    vm.rewindPage()
                }
            }
            return
        }

        guard event.hasPreciseScrollingDeltas else {
            super.scrollWheel(with: event)
            return
        }

        if event.phase == .began {
            swipeAccumX = 0
            swipeAccumY = 0
        }
        swipeAccumX += event.scrollingDeltaX
        swipeAccumY += event.scrollingDeltaY

        if event.phase == .ended {
            let threshold: CGFloat = 36
            defer { swipeAccumX = 0; swipeAccumY = 0 }
            guard abs(swipeAccumX) > abs(swipeAccumY), abs(swipeAccumX) > threshold else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                if swipeAccumX < 0 {
                    vm.advancePage()
                } else {
                    vm.rewindPage()
                }
            }
        }
    }

    // MARK: - Drag & Drop Handling (File Shelf)
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let vm = viewModel else { return [] }
        vm.isDragOverNotch = true
        if !vm.isOpen {
            // Auto open and switch to shelf
            vm.selectPage(1)
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel?.isDragOverNotch = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        viewModel?.isDragOverNotch = false
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty else {
            return false
        }
        ShelfManager.shared.addFiles(urls: items)
        viewModel?.selectPage(1)
        return true
    }
}
