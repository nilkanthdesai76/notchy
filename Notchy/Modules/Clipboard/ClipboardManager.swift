//
//  ClipboardManager.swift
//  Notchy
//
//  Lightweight clipboard history: polls NSPasteboard.changeCount
//  (~0 CPU), skips transient/concealed content and password managers,
//  persists the last 20 items as JSON in Application Support.
//

import AppKit
import Combine
import Foundation

struct ClipboardItem: Codable, Identifiable {
    enum Kind: String, Codable {
        case text
        case image
        case files
    }

    var id = UUID()
    var kind: Kind
    var text: String?
    var imageData: Data?   // jpeg, capped at 480px
    var filePaths: [String]?
    var date = Date()
}

@MainActor
final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var changeCountToSkip: Int?
    private var timer: Timer?

    private let maxItems = 20
    private let maxTextLength = 10_000
    private let maxImageDimension: CGFloat = 480

    private static let blockedTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
    ]
    private static let blockedSourceHints = ["agilebits", "1password", "lastpass", "keychain"]

    init() {
        lastChangeCount = pasteboard.changeCount
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    // MARK: - Polling

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }

        if changeCount == changeCountToSkip {
            // We wrote this change ourselves (re-copy from history).
            lastChangeCount = changeCount
            return
        }
        lastChangeCount = changeCount

        guard !isBlocked() else { return }

        if let item = readCurrentItem() {
            add(item)
        }
    }

    private func isBlocked() -> Bool {
        if let types = pasteboard.types {
            for blocked in Self.blockedTypes where types.contains(blocked) {
                return true
            }
        }
        // Password managers tag their pasteboard items with a source identifier.
        if let source = pasteboard.pasteboardItems?.first?
            .string(forType: NSPasteboard.PasteboardType("org.nspasteboard.Source"))?.lowercased() {
            return Self.blockedSourceHints.contains { source.contains($0) }
        }
        return false
    }

    private func readCurrentItem() -> ClipboardItem? {
        let types = pasteboard.types ?? []

        if types.contains(.string), let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var item = ClipboardItem(kind: .text)
            item.text = String(trimmed.prefix(maxTextLength))
            return item
        }

        if types.contains(.tiff) || types.contains(.png), let image = NSImage(pasteboard: pasteboard) {
            var item = ClipboardItem(kind: .image)
            item.imageData = downscaledJPEG(image)
            return item
        }

        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            var item = ClipboardItem(kind: .files)
            item.filePaths = urls.map(\.path)
            return item
        }

        return nil
    }

    private func downscaledJPEG(_ image: NSImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxImageDimension / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: target, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    // MARK: - Mutation

    private func add(_ item: ClipboardItem) {
        if let first = items.first, isDuplicate(item, first) { return }
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        persist()
    }

    private func isDuplicate(_ a: ClipboardItem, _ b: ClipboardItem) -> Bool {
        a.kind == b.kind && a.text == b.text && a.imageData == b.imageData && a.filePaths == b.filePaths
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .files:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }
        changeCountToSkip = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    func clear() {
        items.removeAll()
        persist()
    }

    // MARK: - Persistence

    private var storageURL: URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("clipboard.json")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
    }
}
