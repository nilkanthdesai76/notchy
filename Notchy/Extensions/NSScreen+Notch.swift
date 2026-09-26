//
//  NSScreen+Notch.swift
//  Notchy
//
//  Notch geometry derived from the screen's safe area insets,
//  the same approach used by NotchDrop / boring.notch / NotchOTP.
//

import AppKit

struct NotchGeometry {
    /// Horizontal center of the notch in screen (global) coordinates.
    let centerX: CGFloat
    /// Physical notch size. Zero when the screen has no notch.
    let size: CGSize
    let hasNotch: Bool
}

extension NSScreen {
    var notchGeometry: NotchGeometry {
        let safeTop = safeAreaInsets.top
        let hasNotch = safeTop > 0
        let left = auxiliaryTopLeftArea?.width ?? 0
        let right = auxiliaryTopRightArea?.width ?? 0
        let width = hasNotch ? max(frame.width - left - right, 0) : 0
        let centerX = hasNotch && left > 0
            ? frame.origin.x + left + width / 2
            : frame.midX
        return NotchGeometry(
            centerX: centerX,
            size: CGSize(width: width, height: safeTop),
            hasNotch: hasNotch
        )
    }
}
