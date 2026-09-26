//
//  PageOrganizerView.swift
//  Notchy
//
//  Interactive visual drag-and-drop page reorganizer.
//  Allows the user to freely reorganize modules across Page 1, Page 2, Page 3,
//  and an unassigned drawer with live drag-and-drop and arrow navigation.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

struct PageOrganizerView: View {
    @ObservedObject var layout = PageLayoutManager.shared
    @State private var draggingModule: NotchyModuleID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Title + Reset Button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("3-Page Layout Customizer")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Drag modules between pages or use arrow buttons to customize your Notch experience.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset to Defaults") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        layout.resetToDefaults()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 3-Page Columns Canvas
            HStack(alignment: .top, spacing: 10) {
                ForEach(0..<3, id: \.self) { pageIndex in
                    if pageIndex < layout.pages.count {
                        PageDropColumn(
                            pageIndex: pageIndex,
                            page: layout.pages[pageIndex],
                            draggingModule: $draggingModule
                        )
                    }
                }
            }

            // Unassigned / Disabled Modules Shelf
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Available / Disabled Modules", systemImage: "tray.2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(layout.unassigned.count) inactive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                UnassignedShelfView(draggingModule: $draggingModule)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Drop Column (Single Page)

private struct PageDropColumn: View {
    let pageIndex: Int
    let page: PageConfig
    @Binding var draggingModule: NotchyModuleID?
    @ObservedObject var layout = PageLayoutManager.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Page Header
            HStack(spacing: 6) {
                Text("\(pageIndex + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.accentColor, in: Circle())

                TextField("Page Title", text: Binding(
                    get: { page.title },
                    set: { layout.updatePageTitle(pageIndex: pageIndex, newTitle: $0) }
                ))
                .font(.system(size: 12, weight: .semibold))
                .textFieldStyle(.plain)

                Spacer()

                Text("\(page.modules.count) items")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            // Droppable Modules Stack
            VStack(spacing: 6) {
                if page.modules.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Drop modules here")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                } else {
                    ForEach(Array(page.modules.enumerated()), id: \.element.id) { index, module in
                        DraggableModuleCard(
                            module: module,
                            pageIndex: pageIndex,
                            cardIndex: index,
                            totalInPage: page.modules.count,
                            draggingModule: $draggingModule
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .onDrop(of: [UTType.text.identifier], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                    guard let raw = string as? String, let module = NotchyModuleID(rawValue: raw) else { return }
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            layout.moveModule(module, toPageIndex: pageIndex)
                        }
                    }
                }
                return true
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Draggable Module Card

private struct DraggableModuleCard: View {
    let module: NotchyModuleID
    let pageIndex: Int
    let cardIndex: Int
    let totalInPage: Int
    @Binding var draggingModule: NotchyModuleID?
    @ObservedObject var layout = PageLayoutManager.shared

    var body: some View {
        HStack(spacing: 7) {
            // Drag Grip Handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.6))
                .cursor(.openHand)

            // Module Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(module.accentColor.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: module.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(module.accentColor)
            }

            // Title & Short Description
            VStack(alignment: .leading, spacing: 1) {
                Text(module.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(module.description)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Quick Reorder Controls
            HStack(spacing: 2) {
                // Move Left or Previous Page
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        layout.moveModuleLeft(module, inPageIndex: pageIndex)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 16)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                .help("Move left / to previous page")

                // Move Right or Next Page
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        layout.moveModuleRight(module, inPageIndex: pageIndex)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 16)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                .help("Move right / to next page")

                // Move to Unassigned (Disable)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        layout.moveModuleToUnassigned(module)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 16)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                .help("Remove from page")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .onDrag {
            self.draggingModule = module
            return NSItemProvider(object: module.id as NSString)
        }
    }
}

// MARK: - Unassigned Shelf

private struct UnassignedShelfView: View {
    @Binding var draggingModule: NotchyModuleID?
    @ObservedObject var layout = PageLayoutManager.shared
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            if layout.unassigned.isEmpty {
                Text("All modules are assigned to active pages. Drag cards here to disable them.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(layout.unassigned) { module in
                            HStack(spacing: 5) {
                                Image(systemName: module.iconName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(module.accentColor)
                                Text(module.shortTitle)
                                    .font(.system(size: 10, weight: .medium))

                                Menu {
                                    ForEach(Array(layout.pages.enumerated()), id: \.element.id) { pIndex, page in
                                        Button("Add to Page \(pIndex + 1) (\(page.title))") {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                layout.moveModule(module, toPageIndex: pIndex)
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 16, height: 16)
                                        .background(Color.secondary.opacity(0.12), in: Circle())
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .help("Add \(module.title) to a page")
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                            .onDrag {
                                self.draggingModule = module
                                return NSItemProvider(object: module.id as NSString)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onDrop(of: [UTType.text.identifier], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                guard let raw = string as? String, let module = NotchyModuleID(rawValue: raw) else { return }
                Task { @MainActor in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        layout.moveModuleToUnassigned(module)
                    }
                }
            }
            return true
        }
    }
}

// Cursor modifier extension
private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovered in
            if isHovered {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
