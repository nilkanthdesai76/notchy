//
//  ShelfManager.swift
//  Notchy
//
//  Manages staged files dropped into the notch or file shelf,
//  with quick preview, Finder reveal, and native AirDrop sharing.
//

import AppKit
import Combine
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let sizeString: String
    let icon: NSImage
    let dateAdded: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.dateAdded = Date()

        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            self.sizeString = formatter.string(fromByteCount: Int64(size))
        } else {
            self.sizeString = ""
        }
    }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.url == rhs.url
    }
}

@MainActor
final class ShelfManager: NSObject, ObservableObject, NSSharingServiceDelegate {
    static let shared = ShelfManager()

    @Published var items: [ShelfItem] = []
    @Published var isTargeted: Bool = false

    private let storageKey = "NotchyShelfItems"

    override init() {
        super.init()
        loadSavedItems()
    }

    func addFiles(urls: [URL]) {
        for url in urls {
            if !items.contains(where: { $0.url == url }) {
                items.insert(ShelfItem(url: url), at: 0)
            }
        }
        saveItems()
    }

    func remove(item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func clear() {
        items.removeAll()
        saveItems()
    }

    func openFile(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func shareAirDrop(itemsToShare: [ShelfItem]? = nil) {
        let targets = (itemsToShare ?? items).map { $0.url }
        guard !targets.isEmpty else { return }

        if let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: targets) {
            service.delegate = self
            service.perform(withItems: targets)
        } else {
            let picker = NSSharingServicePicker(items: targets)
            if let window = NSApp.keyWindow, let view = window.contentView {
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            }
        }
    }

    private func saveItems() {
        let paths = items.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: storageKey)
    }

    private func loadSavedItems() {
        guard let paths = UserDefaults.standard.stringArray(forKey: storageKey) else { return }
        var loaded: [ShelfItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                loaded.append(ShelfItem(url: url))
            }
        }
        self.items = loaded
    }
}
