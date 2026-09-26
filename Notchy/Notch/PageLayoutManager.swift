//
//  PageLayoutManager.swift
//  Notchy
//
//  Manages the customizable module layout across dynamic notch carousel pages.
//  Supports dynamic page adding/removing, drag-and-drop reordering, and persistence.
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
    case otp = "otp"
    case timer = "timer"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return "Media Controls"
        case .clipboard: return "Clipboard History"
        case .camera: return "Webcam Mirror"
        case .shelf: return "Shelf & AirDrop"
        case .stats: return "System Stats"
        case .aiUsage: return "AI Token Usage"
        case .otp: return "2FA Authenticator"
        case .timer: return "Focus Timer"
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
        case .otp: return "2FA"
        case .timer: return "Timer"
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
        case .otp: return "key.fill"
        case .timer: return "timer"
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
        case .otp: return .purple
        case .timer: return .red
        }
    }

    var description: String {
        switch self {
        case .media: return "Playback controls & audio visualizer"
        case .clipboard: return "Recent clipboard history with 1-click paste"
        case .camera: return "Portrait rounded rectangle selfie mirror"
        case .shelf: return "File staging area and direct AirDrop"
        case .stats: return "Live CPU, RAM, Network & Quick Tools"
        case .aiUsage: return "Antigravity, Claude, Kimi token metrics"
        case .otp: return "2FA TOTP accounts with countdown rings"
        case .timer: return "Pomodoro & quick interval focus timer"
        }
    }
}

// MARK: - Page Configuration

struct PageConfig: Identifiable, Codable, Equatable {
    var id: Int
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

    private let storageKey = "notchy_page_layouts_v3"

    init() {
        loadLayout()
    }

    func loadLayout() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedLayout.self, from: data),
           !saved.pages.isEmpty {
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
            PageConfig(id: 0, modules: [.media, .clipboard, .camera]),
            PageConfig(id: 1, modules: [.shelf, .stats]),
            PageConfig(id: 2, modules: [.aiUsage, .otp, .timer])
        ]
        unassigned = []
        saveLayout()
    }

    // MARK: - Dynamic Page Management

    func addPage() {
        let nextId = (pages.map(\.id).max() ?? -1) + 1
        pages.append(PageConfig(id: nextId, modules: []))
        saveLayout()
    }

    func removePage(at index: Int) {
        guard pages.count > 1, index >= 0 && index < pages.count else { return }
        let removedModules = pages[index].modules
        unassigned.append(contentsOf: removedModules)
        pages.remove(at: index)
        // Re-index pages
        for i in 0..<pages.count {
            pages[i].id = i
        }
        saveLayout()
    }

    // MARK: - Reordering & Transfer Operations

    func moveModule(_ module: NotchyModuleID, toPageIndex targetPageIndex: Int, atIndex targetIndex: Int? = nil) {
        guard targetPageIndex >= 0 && targetPageIndex < pages.count else { return }
        // Hard limit: max 3 modules per page
        if pages[targetPageIndex].modules.count >= 3 && !pages[targetPageIndex].modules.contains(module) {
            return
        }

        removeModuleFromAll(module)

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
        } else if pageIndex > 0 && pages[pageIndex - 1].modules.count < 3 {
            // Move to previous page if it has room
            moveModule(module, toPageIndex: pageIndex - 1)
        }
    }

    func moveModuleRight(_ module: NotchyModuleID, inPageIndex pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pages.count else { return }
        guard let idx = pages[pageIndex].modules.firstIndex(of: module) else { return }
        if idx < pages[pageIndex].modules.count - 1 {
            pages[pageIndex].modules.swapAt(idx, idx + 1)
            saveLayout()
        } else if pageIndex < pages.count - 1 && pages[pageIndex + 1].modules.count < 3 {
            // Move to next page if it has room
            moveModule(module, toPageIndex: pageIndex + 1, atIndex: 0)
        }
    }

    private func removeModuleFromAll(_ module: NotchyModuleID) {
        for i in 0..<pages.count {
            pages[i].modules.removeAll(where: { $0 == module })
        }
        unassigned.removeAll(where: { $0 == module })
    }
}
