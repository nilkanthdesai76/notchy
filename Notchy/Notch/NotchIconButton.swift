//
//  NotchIconButton.swift
//  Notchy
//
//  Circular icon button with hover + press feedback, used across the panel.
//

import SwiftUI

struct NotchIconButton: View {
    let systemName: String
    var fontSize: CGFloat = 13
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(hovering ? 0.16 : 0.07), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Press feedback shared by all panel buttons.
struct NotchPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
