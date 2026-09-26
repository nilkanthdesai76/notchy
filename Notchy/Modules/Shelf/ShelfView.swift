//
//  ShelfView.swift
//  Notchy
//
//  File shelf staging tray with drag & drop and 1-click native AirDrop.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var shelf = ShelfManager.shared
    @Environment(\.moduleCornerRadii) private var radii
    @Environment(\.cardSlotCount) private var cardSlotCount
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: cardSlotCount == 1 ? 9 : 8) {
            // Header Row: Title + AirDrop All + Clear
            HStack(spacing: 8) {
                Label("File Shelf", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: cardSlotCount == 1 ? 12 : 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                if !shelf.items.isEmpty {
                    Text("\(shelf.items.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }

                if cardSlotCount == 1 {
                    Text("• Drag & Drop Staging Ground")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)

                if !shelf.items.isEmpty {
                    Button {
                        shelf.shareAirDrop()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "airdrop")
                                .font(.system(size: 10, weight: .bold))
                            Text("AirDrop All")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.blue.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button("Clear") {
                        shelf.clear()
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .buttonStyle(.plain)
                }
            }

            // Shelf Content / Drop Target
            if shelf.items.isEmpty {
                dropZonePlaceholder
            } else if cardSlotCount == 1 {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 5) {
                        ForEach(shelf.items) { item in
                            ShelfItemCard(item: item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(shelf.items) { item in
                            ShelfItemCard(item: item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod()
        .overlay(
            radii.asShape
                .strokeBorder(isTargeted ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            loadDroppedFiles(from: providers)
            return true
        }
    }

    private var dropZonePlaceholder: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "tray.fill")
                .font(.system(size: cardSlotCount == 1 ? 28 : 24))
                .foregroundStyle(isTargeted ? Color.blue : Color.white.opacity(0.2))
                .scaleEffect(isTargeted ? 1.15 : 1.0)
                .animation(.spring(response: 0.3), value: isTargeted)
            Text(isTargeted ? "Drop Files Here" : "Drag files here to stage & AirDrop")
                .font(.system(size: cardSlotCount == 1 ? 11 : 10, weight: .medium))
                .foregroundStyle(.white.opacity(isTargeted ? 0.9 : 0.4))
            if cardSlotCount == 1 {
                Text("Hover items over the notch anytime to drop from any app")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadDroppedFiles(from providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        urls.append(url)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            shelf.addFiles(urls: urls)
        }
    }
}

private struct ShelfItemCard: View {
    let item: ShelfItem
    @ObservedObject var shelf = ShelfManager.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                if !item.sizeString.isEmpty {
                    Text(item.sizeString)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 4)

            // Actions: AirDrop, Reveal, Remove
            HStack(spacing: 4) {
                Button {
                    shelf.shareAirDrop(itemsToShare: [item])
                } label: {
                    Image(systemName: "airdrop")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue.opacity(0.85))
                        .padding(4)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("AirDrop file")

                Button {
                    shelf.revealInFinder(item)
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(4)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    shelf.remove(item: item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(4)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from shelf")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Color.white.opacity(isHovered ? 0.10 : 0.04),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            shelf.openFile(item)
        }
    }
}
