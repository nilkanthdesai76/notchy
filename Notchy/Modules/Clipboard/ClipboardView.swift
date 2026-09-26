//
//  ClipboardView.swift
//  Notchy
//
//  Searchable clipboard history partitioned for 60% panel width.
//

import SwiftUI
import Combine

struct ClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardManager
    @State private var searchText: String = ""
    @State private var copiedId: UUID?

    private var filteredItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return clipboard.items
        }
        return clipboard.items.filter { item in
            if let text = item.text, text.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            if let files = item.filePaths, files.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                return true
            }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Title + Search Field + Clear Button
            HStack(spacing: 8) {
                Label("Clipboard", systemImage: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                // Search Bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Spacer(minLength: 0)

                if !clipboard.items.isEmpty {
                    Button("Clear") {
                        clipboard.clear()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .buttonStyle(.plain)
                }
            }

            // Items List
            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.15))
                    Text(searchText.isEmpty ? "Copy text or images to see them here" : "No matches found")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(item: item, isCopied: copiedId == item.id) {
                                clipboard.copy(item)
                                copiedId = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    if copiedId == item.id {
                                        copiedId = nil
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod(cornerRadius: 16)
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                // Icon
                switch item.kind {
                case .text:
                    if let text = item.text, text.hasPrefix("http://") || text.hasPrefix("https://") {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue.opacity(0.8))
                    } else if let text = item.text, text.hasPrefix("#"), text.count == 7 {
                        Circle()
                            .fill(Color(hex: text) ?? .white)
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text(item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                case .image:
                    Image(systemName: "photo")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple.opacity(0.8))
                    Text("Image")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                case .files:
                    Image(systemName: "doc.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text((item.filePaths ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Copied")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                } else {
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Color.white.opacity(isHovered ? 0.12 : 0.04),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt64(str, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
