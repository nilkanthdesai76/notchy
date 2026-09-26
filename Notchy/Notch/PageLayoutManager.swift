//
//  PageLayoutManager.swift
//  Notchy
//
//  Manages the customizable module layout across the 3 notch carousel pages.
//  Supports full drag-and-drop reordering, inter-page transfer, and persistence.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Module Identifier & Metadata

enum NotchyModuleID: String, CaseIterable, Identifiable, Codable {
    case media = "media"
    case clipboard = "clipboard"
    case camera = "camera"
    case shelf = "shelf"
    case stats = "stats"
    case aiUsage = "aiUsage"
    case security = "security"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return "Media Controls"
        case .clipboard: return "Clipboard History"
        case .camera: return "Webcam Mirror"
        case .shelf: return "Shelf & AirDrop"
        case .stats: return "Stats & Tools"
        case .aiUsage: return "AI Token Usage"
        case .security: return "2FA & Focus Timer"
        }
    }

    var shortTitle: String {
        switch self {
        case .media: return "Media"
        case .clipboard: return "Clips"
        case .camera: return "Mirror"
        case .shelf: return "Shelf"
        case .stats: return "Stats"
        case .aiUsage: return "AI"
        case .security: return "2FA/Timer"
        }
    }

    var iconName: String {
        switch self {
        case .media: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        case .camera: return "video.fill"
        case .shelf: return "tray.and.arrow.down.fill"
        case .stats: return "cpu"
        case .aiUsage: return "sparkles"
        case .security: return "lock.shield.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .media: return .green
        case .clipboard: return .blue
        case .camera: return .mint
        case .shelf: return .indigo
        case .stats: return .orange
        case .aiUsage: return .cyan
        case .security: return .purple
        }
    }

    var description: String {
        switch self {
        case .media: return "Playback controls & audio visualizer"
        case .clipboard: return "Recent clipboard history with 1-click paste"
        case .camera: return "Portrait rounded rectangle selfie mirror"
        case .shelf: return "File staging area and direct AirDrop"
        case .stats: return "CPU/RAM/Net stats + Caffeinate & Eyedropper"
        case .aiUsage: return "Antigravity, Kimi, OpenCode token metrics"
        case .security: return "2FA OTP codes and Pomodoro focus timer"
        }
    }
}

// MARK: - Page Configuration

struct PageConfig: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var modules: [NotchyModuleID]
}

private struct SavedLayout: Codable {
    var pages: [PageConfig]
    var unassigned: [NotchyModuleID]
}

// MARK: - Layout Manager

@MainActor
final class PageLayoutManager: ObservableObject {
    static let shared = PageLayoutManager()

    @Published var pages: [PageConfig] = []
    @Published var unassigned: [NotchyModuleID] = []

    /// Active pages containing at least one enabled module.
    /// Pages with all modules disabled/unassigned are completely omitted.
    var activePages: [PageConfig] {
        pages.filter { !$0.modules.isEmpty }
    }

    private let storageKey = "notchy_page_layouts_v2"

    init() {
        loadLayout()
    }

    func loadLayout() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedLayout.self, from: data),
           saved.pages.count == 3 {
            self.pages = saved.pages
            self.unassigned = saved.unassigned
        } else {
            resetToDefaults()
        }
    }

    func saveLayout() {
        let saved = SavedLayout(pages: pages, unassigned: unassigned)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func resetToDefaults() {
        pages = [
            PageConfig(id: 0, title: "Studio", modules: [.media, .clipboard, .camera]),
            PageConfig(id: 1, title: "Shelf & Stats", modules: [.shelf, .stats]),
            PageConfig(id: 2, title: "AI & 2FA", modules: [.aiUsage, .security])
        ]
        unassigned = []
        saveLayout()
    }

    // MARK: - Reordering & Transfer Operations

    func moveModule(_ module: NotchyModuleID, toPageIndex targetPageIndex: Int, atIndex targetIndex: Int? = nil) {
        removeModuleFromAll(module)

        guard targetPageIndex >= 0 && targetPageIndex < pages.count else { return }
        if let targetIndex = targetIndex, targetIndex <= pages[targetPageIndex].modules.count {
            pages[targetPageIndex].modules.insert(module, at: targetIndex)
        } else {
            pages[targetPageIndex].modules.append(module)
        }
        saveLayout()
    }

    func moveModuleToUnassigned(_ module: NotchyModuleID) {
        removeModuleFromAll(module)
        unassigned.append(module)
        saveLayout()
    }

    func moveModuleLeft(_ module: NotchyModuleID, inPageIndex pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pages.count else { return }
        guard let idx = pages[pageIndex].modules.firstIndex(of: module) else { return }
        if idx > 0 {
            pages[pageIndex].modules.swapAt(idx, idx - 1)
            saveLayout()
        } else if pageIndex > 0 {
            // Move to previous page
            moveModule(module, toPageIndex: pageIndex - 1)
        }
    }

    func moveModuleRight(_ module: NotchyModuleID, inPageIndex pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pages.count else { return }
        guard let idx = pages[pageIndex].modules.firstIndex(of: module) else { return }
        if idx < pages[pageIndex].modules.count - 1 {
            pages[pageIndex].modules.swapAt(idx, idx + 1)
            saveLayout()
        } else if pageIndex < pages.count - 1 {
            // Move to next page
            moveModule(module, toPageIndex: pageIndex + 1, atIndex: 0)
        }
    }

    func updatePageTitle(pageIndex: Int, newTitle: String) {
        guard pageIndex >= 0 && pageIndex < pages.count else { return }
        pages[pageIndex].title = newTitle
        saveLayout()
    }

    private func removeModuleFromAll(_ module: NotchyModuleID) {
        for i in 0..<pages.count {
            pages[i].modules.removeAll(where: { $0 == module })
        }
        unassigned.removeAll(where: { $0 == module })
    }
}
