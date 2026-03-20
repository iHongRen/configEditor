//
//  SidebarView.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct GroupDropDelegate: DropDelegate {
    let targetGroup: ConfigGroup
    @Binding var draggedGroupID: String?
    @Binding var dropTargetGroupID: String?
    let configManager: ConfigManager

    func dropEntered(info: DropInfo) {
        guard let draggedGroupID,
              draggedGroupID != targetGroup.id else {
            return
        }

        dropTargetGroupID = targetGroup.id
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            configManager.moveGroup(from: draggedGroupID, to: targetGroup.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGroupID = nil
        dropTargetGroupID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedGroupID != nil
    }

    func dropExited(info: DropInfo) {
        if dropTargetGroupID == targetGroup.id {
            dropTargetGroupID = nil
        }
    }
}

private struct GroupTrailingDropDelegate: DropDelegate {
    @Binding var draggedGroupID: String?
    @Binding var dropTargetGroupID: String?
    let configManager: ConfigManager

    func dropEntered(info: DropInfo) {
        guard let draggedGroupID else {
            return
        }

        dropTargetGroupID = "end-of-groups"
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            configManager.moveGroupToEnd(draggedGroupID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGroupID = nil
        dropTargetGroupID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedGroupID != nil
    }

    func dropExited(info: DropInfo) {
        if dropTargetGroupID == "end-of-groups" {
            dropTargetGroupID = nil
        }
    }
}


// Custom slider that only displays a track (we draw) and a circular thumb.
// - value: bound Double
// - range: value range
// - gradient: background fill for the track
struct ColorSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var gradient: LinearGradient
    var thumbSize: CGFloat = 18
    var trackHeight: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            // usable width for thumb travel
            let usable = max(1, totalWidth - thumbSize)
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = thumbSize / 2 + fraction * usable

            ZStack {
                // track (integrated Capsule)
                Capsule()
                    .fill(gradient)
                    .frame(height: trackHeight)
                    .padding(.horizontal, 0)

                // thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                    .position(x: thumbX, y: geo.size.height / 2)
                    // Visual-only; interaction handled by gesture on ZStack so hit area is larger

            }
            .contentShape(Rectangle())
            // DragGesture with minimumDistance 0 handles both clicks and drags (tap-to-jump + drag)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    // location.x is in GeometryReader coords
                    let localX = min(max(g.location.x - thumbSize / 2, 0), usable)
                    let frac = Double(localX / usable)
                    let newVal = range.lowerBound + frac * (range.upperBound - range.lowerBound)
                    // update without animation for direct feel
                    value = min(max(range.lowerBound, newVal), range.upperBound)
                }
            )
        }
        .frame(height: max(thumbSize, 28))
    }
}

// TagNameEditor: a combined WYSIWYG tag name input + preview.
// Uses AppKit text measurement for reliable width updates on macOS.
struct TagNameEditor: View {
    @Binding var text: String
    @Binding var r: Double
    @Binding var g: Double
    @Binding var b: Double
    @Binding var a: Double

    var fontSize: CGFloat = 15

    private var bgColor: Color {
        Color(red: r/255.0, green: g/255.0, blue: b/255.0).opacity(a)
    }

    private let height: CGFloat = 30
    private let horizontalPadding: CGFloat = 20 // left + right
    @FocusState private var isFocused: Bool
    @State private var caretVisible: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            TextField("", text: $text)
                .font(.system(size: fontSize))
                .textFieldStyle(PlainTextFieldStyle())
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalPadding/2)
                .frame(width: currentWidth(), height: height)
                .background(bgColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .compatibleOnChange(of: text) { _, new in
                    // 限制标签字数：中文 5 字，英文 10 字
                    let hasHan = new.range(of: "\\p{Han}", options: .regularExpression) != nil
                    let maxLen = hasHan ? 5 : 10
                    if new.count > maxLen {
                        text = String(new.prefix(maxLen))
                    }
                    // If text becomes empty via keyboard (cmd+delete) ensure field stays focused so our custom caret can show
                    if new.isEmpty {
                        DispatchQueue.main.async {
                            self.isFocused = true
                        }
                    }
                }
                .focused($isFocused)
                .onAppear {
                    // Ensure caret is at end (no full-selection) when the sheet appears for existing tags
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        // try to move the NSTextView selection to end if possible
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            let length = (editor.string as NSString).length
                            editor.setSelectedRange(NSRange(location: length, length: 0))
                        }
                        // ensure this field is focused
                        self.isFocused = true
                    }
                }
                // blink caret for empty state
                .onReceive(Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()) { _ in
                    caretVisible.toggle()
                }
                .overlay(
                    Group {
                        if text.isEmpty && isFocused {
                            // custom caret centered inside the capsule
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 1, height: height * 0.5)
                                .opacity(caretVisible ? 1 : 0)
                                .animation(.linear(duration: 0.05), value: caretVisible)
                        }
                    }
                )
        }
    }

    private func textWidth() -> CGFloat {
        if text.isEmpty { return 0 }
        let font = NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        return ceil(size.width)
    }

    private func currentWidth() -> CGFloat {
        if text.isEmpty { return height }
        let extra: CGFloat = 8
        let w = textWidth() + horizontalPadding + extra
        return max(height, w)
    }
}

private struct GroupEditorState: Identifiable {
    let id = UUID()
    let groupID: String?
    var name: String
    let title: String
    let actionTitle: String
}

struct SidebarView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject private var localization = LocalizationSettings.shared
    @Binding var selectedFile: ConfigFile?
    @Binding var searchText: String
    @Binding var showFileImporter: Bool
    @Binding var globalZoomLevel: Double
    @Binding var contextMenuFile: ConfigFile?
    @Binding var showDeleteAlert: Bool
    @Binding var fileContent: String
    @Binding var originalFileContent: String
    @Binding var fileSize: Int64
    @Binding var fileModificationDate: Date?

    // Tagging UI state
    @State private var tagTextInput: String = ""
    // default tag color: red (matching presets)
    @State private var tagR: Double = 255
    @State private var tagG: Double = 59
    @State private var tagB: Double = 48
    @State private var tagA: Double = 1.0
    @State private var tagEditorFile: ConfigFile?
    @State private var groupEditorState: GroupEditorState?
    @State private var pendingDeleteGroup: ConfigGroup?
    @State private var draggedGroupID: String?
    @State private var dropTargetGroupID: String?

    private var filteredFiles: [ConfigFile] {
        configManager.visibleFiles(searchText: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ZStack {
                    TextField(L10n.tr("search.config.file.placeholder"), text: $searchText, prompt: Text(L10n.tr("search.config.files.prompt")))
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.leading, 12)
                        .disableAutocorrection(true)
                        .frame(height: 28 * globalZoomLevel)
                        .font(.system(size: 13 * globalZoomLevel))

                    if !searchText.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 24 * globalZoomLevel, height: 28 * globalZoomLevel)
                            .padding(.trailing, 2)
                        }
                    }
                }
                .frame(height: 40 * globalZoomLevel)

                Button(action: { showFileImporter = true }) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 20 * globalZoomLevel, height: 20 * globalZoomLevel)
                        .foregroundColor(.accentColor)
                        .help(L10n.tr("add.custom.config.file"))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
            }
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            groupChip(title: "全部", groupID: nil, isEditable: false)
                                .id("all-groups")

                            ForEach(configManager.groups) { group in
                                groupChip(title: group.name, groupID: group.id, isEditable: true)
                                    .id(group.id)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: GroupDropDelegate(
                                            targetGroup: group,
                                            draggedGroupID: $draggedGroupID,
                                            dropTargetGroupID: $dropTargetGroupID,
                                            configManager: configManager
                                        )
                                    )
                            }

                            if draggedGroupID != nil {
                                Capsule()
                                    .fill(dropTargetGroupID == "end-of-groups" ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                dropTargetGroupID == "end-of-groups" ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.18),
                                                style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                                            )
                                    )
                                    .frame(width: 44 * globalZoomLevel, height: 34 * globalZoomLevel)
                                    .overlay(
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12 * globalZoomLevel, weight: .semibold))
                                            .foregroundColor(dropTargetGroupID == "end-of-groups" ? .accentColor : .secondary)
                                    )
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: GroupTrailingDropDelegate(
                                            draggedGroupID: $draggedGroupID,
                                            dropTargetGroupID: $dropTargetGroupID,
                                            configManager: configManager
                                        )
                                    )
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 6)
                        .padding(.vertical, 4)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configManager.groups)
                        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: draggedGroupID)
                        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: dropTargetGroupID)
                    }
                    .onAppear {
                        scrollSelectedGroupIntoView(using: proxy, animated: false)
                    }
                    .compatibleOnChange(of: configManager.selectedGroupID) { _, _ in
                        scrollSelectedGroupIntoView(using: proxy)
                    }
                    .compatibleOnChange(of: configManager.groups) { _, _ in
                        scrollSelectedGroupIntoView(using: proxy)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 4)

                Button(action: {
                    groupEditorState = GroupEditorState(groupID: nil, name: "", title: L10n.tr("new.group.title"), actionTitle: L10n.tr("new.group.create"))
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 18 * globalZoomLevel, height: 18 * globalZoomLevel)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
                .help(L10n.tr("new.group.title"))
            }
            .padding(.bottom, 8)

            if filteredFiles.isEmpty {
                VStack(spacing: 14 * globalZoomLevel) {
                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 22 * globalZoomLevel, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.16),
                                        Color.accentColor.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 116 * globalZoomLevel, height: 116 * globalZoomLevel)

                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 40 * globalZoomLevel, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    VStack(spacing: 6 * globalZoomLevel) {
                        Text(L10n.tr("list.empty.title"))
                            .font(.system(size: 16 * globalZoomLevel, weight: .semibold))

                        Text(L10n.tr("list.empty.description"))
                            .font(.system(size: 12 * globalZoomLevel))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24 * globalZoomLevel)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedFile) {
                    ForEach(filteredFiles) { file in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 13 * globalZoomLevel))

                                if let parentDirectoryName = file.parentDirectoryName {
                                    Text(parentDirectoryName)
                                        .font(.system(size: 11 * globalZoomLevel))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // Tag bubble display (capsule)
                            if let tag = file.tag {
                                let bg = Color(red: tag.r, green: tag.g, blue: tag.b).opacity(tag.a)
                           
                                let fgColor: Color = .white
                                if tag.text.isEmpty {
                                        Circle()
                                            .fill(bg)
                                            .frame(width: 12, height: 12)
                                            .onTapGesture(count: 2) {
                                                tagTextInput = tag.text
                                                tagR = tag.r * 255.0
                                                tagG = tag.g * 255.0
                                                tagB = tag.b * 255.0
                                                tagA = tag.a
                                                tagEditorFile = file
                                            }
                                } else {
                                    Text(tag.text)
                                        .font(.system(size: 9 * globalZoomLevel))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(bg)
                                        .foregroundColor(fgColor)
                                        .clipShape(Capsule())
                                        .onTapGesture(count: 2) {
                                   
                                            // prepare state first, then present sheet by setting contextMenuFile
                                            tagTextInput = tag.text
                                            tagR = tag.r * 255.0
                                            tagG = tag.g * 255.0
                                            tagB = tag.b * 255.0
                                            tagA = tag.a
                                            tagEditorFile = file
                                        }
                                }
                            }
                            Spacer()
                            if file.isPinned {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 13 * globalZoomLevel))
                            }
                        }
                        .help(file.path)
                        .padding(.vertical, 5 * globalZoomLevel)
                        .padding(.horizontal, 8 * globalZoomLevel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (selectedFile == file) ? Color.accentColor.opacity(0.3) : (file.isPinned ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                        .cornerRadius(6)
                        .tag(file as ConfigFile?)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFile = file
                            FileOperations.loadAndSetFileContent(file: file, fileContent: $fileContent, originalFileContent: $originalFileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                        }
                        .contextMenu {
                            Button(action: {
                                configManager.togglePin(for: file)
                            }) {
                                HStack {
                                    Image(systemName: file.isPinned ? "pin.slash" : "pin")
                                    Text(file.isPinned ? L10n.tr("unpin") : L10n.tr("pin"))
                                }
                            }

                            Button(action: {
                                // prepare popover state first, then set contextMenuFile to present sheet
                                if let tag = file.tag {
                                    tagTextInput = tag.text
                                    tagR = tag.r * 255.0
                                    tagG = tag.g * 255.0
                                    tagB = tag.b * 255.0
                                    tagA = tag.a
                                } else {
                                    tagTextInput = ""
                                    // default to red
                                    tagR = 255
                                    tagG = 59
                                    tagB = 48
                                    tagA = 1.0
                                }
                                tagEditorFile = file
                            }) {
                                HStack {
                                    Image(systemName: "tag")
                                    Text(L10n.tr("tag"))
                                }
                            }

                            Menu {
                                Button(action: {
                                    configManager.moveFile(file, to: nil)
                                }) {
                                    HStack {
                                        if file.groupID == nil {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(L10n.tr("all.groups"))
                                    }
                                }

                                if !configManager.groups.isEmpty {
                                    Divider()
                                }

                                ForEach(configManager.groups) { group in
                                    Button(action: {
                                        configManager.moveFile(file, to: group.id)
                                    }) {
                                        HStack {
                                            if file.groupID == group.id {
                                                Image(systemName: "checkmark")
                                            }
                                            Text(group.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "folder.badge.gearshape")
                                    Text(L10n.tr("move.to.group"))
                                }
                            }

                            Divider()

                            Button(action: {
                                FileOperations.copyPathToClipboard(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text(L10n.tr("copy.path"))
                                }
                            }

                            Button(action: {
                                FileOperations.openInFinder(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(L10n.tr("open.in.finder"))
                                }
                            }

                            Button(action: {
                                FileOperations.openInCode(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "highlighter")
                                    Text(L10n.tr("open.in.vscode"))
                                }
                            }

                            Button(action: {
                                FileOperations.openInCursor(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                    Text(L10n.tr("open.in.cursor"))
                                }
                            }

                            Button(action: {
                                FileOperations.openInTerminal(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "terminal")
                                    Text(L10n.tr("open.in.terminal"))
                                }
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                contextMenuFile = file
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(L10n.tr("delete"))
                                }
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let name = url.lastPathComponent
                    let path = url.path

                    if !configManager.configFiles.contains(where: { $0.path == path }) {
                        let newConfig = ConfigFile(name: name, path: path, isCustom: true, groupID: configManager.selectedGroupID)
                        configManager.addConfigFile(newConfig)
                        selectedFile = newConfig
                        FileOperations.loadAndSetFileContent(file: newConfig, fileContent: $fileContent, originalFileContent: $originalFileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                    }
                }
            default:
                break
            }
        }
        .compatibleOnChange(of: searchText) { _, _ in
            syncSelectionWithVisibleFiles()
        }
        .compatibleOnChange(of: configManager.selectedGroupID) { _, _ in
            syncSelectionWithVisibleFiles()
        }
        .compatibleOnChange(of: configManager.configFiles) { _, _ in
            syncSelectionWithVisibleFiles()
        }

    // Tagging sheet (item-based) - improved layout
    .sheet(item: $tagEditorFile) { target in
            VStack(spacing: 16) {
                Text(L10n.tr("add.tag"))
                    .font(.title3)
                    .padding(.top, 16)

                // WYSIWYG Tag editor: combined input + preview
                HStack {
                    TagNameEditor(text: $tagTextInput, r: $tagR, g: $tagG, b: $tagB, a: $tagA)
                }
                .padding(.horizontal)

                // Quick colors under input
                VStack(alignment: .leading, spacing: 8) {
                   

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            let presets: [[Double]] = [
                                [255, 59, 48],
                                [255, 149, 0],
                                [255, 204, 0],
                                [52, 199, 89],
                                [0, 122, 255],
                                [88, 86, 214],
                                [142, 142, 147]
                            ]

                            ForEach(presets.indices, id: \.self) { i in
                                let p = presets[i]
                                Button(action: {
                                    tagR = p[0]
                                    tagG = p[1]
                                    tagB = p[2]
                                    tagA = 1.0
                                }) {
                                    Circle()
                                        .fill(Color(red: p[0]/255.0, green: p[1]/255.0, blue: p[2]/255.0))
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
           
                
                // Actions: Delete (left) | Cancel | Save (right) - styled consistently
                HStack(spacing: 12) {
                    
                    // Cancel (filled but subtle)
                    Button(action: { tagEditorFile = nil }) {
                        Text(L10n.tr("cancel"))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()

                    if target.tag != nil {
                        Button(action: {
                            configManager.setTag(nil, for: target)
                            tagEditorFile = nil
                        }) {
                            Text(L10n.tr("delete"))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Save (primary)
                    Button(action: {
                        let tag = FileTag(text: tagTextInput, r: (tagR/255.0), g: (tagG/255.0), b: (tagB/255.0), a: tagA)
                        configManager.setTag(tag, for: target)
                        tagEditorFile = nil
                    }) {
                        Text(L10n.tr("save"))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding([.horizontal, .bottom])
            }
            .frame(width: 280)
        }
        .sheet(item: $groupEditorState) { state in
            VStack(alignment: .leading, spacing: 16) {
                Text(state.title)
                    .font(.title3)

                TextField(L10n.tr("group.name.placeholder"), text: Binding(
                    get: { groupEditorState?.name ?? state.name },
                    set: { groupEditorState?.name = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())

                HStack {
                    Spacer()

                    Button(L10n.tr("cancel")) {
                        groupEditorState = nil
                    }

                    Button(state.actionTitle) {
                        saveGroupEditor()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
        .alert(L10n.tr("delete.group"), isPresented: Binding(
            get: { pendingDeleteGroup != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteGroup = nil
                }
            }
        )) {
            Button(L10n.tr("cancel"), role: .cancel) {
                pendingDeleteGroup = nil
            }
            Button(L10n.tr("delete"), role: .destructive) {
                if let group = pendingDeleteGroup {
                    configManager.deleteGroup(id: group.id)
                }
                pendingDeleteGroup = nil
            }
        } message: {
            Text(L10n.language == .chinese ? "删除后，该分组下的配置文件会保留，但会回到“全部分组”。" : "Deleting a group keeps its config files, but moves them back to All.")
        }
    }

    @ViewBuilder
    private func groupChip(title: String, groupID: String?, isEditable: Bool) -> some View {
        let isSelected = selectedGroupChipID == (groupID ?? "all-groups")
        let chipID = groupID ?? "all-groups"
        let isDragged = groupID != nil && draggedGroupID == groupID
        let isDropTarget = groupID != nil && dropTargetGroupID == groupID

        Text(title)
            .font(.system(size: 12 * globalZoomLevel, weight: isSelected ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor(isSelected: isSelected, isDropTarget: isDropTarget))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor(isSelected: isSelected, isDropTarget: isDropTarget), lineWidth: isDropTarget ? 1.4 : 1)
            )
            .contentShape(Capsule())
            .scaleEffect(isDragged ? 1.06 : (isDropTarget ? 1.03 : 1.0))
            .opacity(isDragged ? 0.72 : 1.0)
            .shadow(color: shadowColor(isDragged: isDragged, isDropTarget: isDropTarget), radius: isDragged ? 10 : 5, x: 0, y: isDragged ? 6 : 3)
            .padding(.vertical, 2)
            .onTapGesture {
                configManager.selectGroup(groupID)
            }
            .onDrag {
                guard isEditable else {
                    return NSItemProvider()
                }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    draggedGroupID = groupID
                    dropTargetGroupID = nil
                }
                return NSItemProvider(object: chipID as NSString)
            }
            .contextMenu {
                if isEditable, let groupID, let group = configManager.groups.first(where: { $0.id == groupID }) {
                    Button(L10n.tr("edit")) {
                        groupEditorState = GroupEditorState(groupID: group.id, name: group.name, title: L10n.tr("edit"), actionTitle: L10n.tr("save"))
                    }

                    Button(L10n.tr("delete"), role: .destructive) {
                        pendingDeleteGroup = group
                    }
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.84), value: isDragged)
            .animation(.spring(response: 0.24, dampingFraction: 0.84), value: isDropTarget)
    }

    private func syncSelectionWithVisibleFiles() {
        let files = filteredFiles

        if let selectedFile, files.contains(selectedFile) {
            return
        }

        guard let firstFile = files.first else {
            selectedFile = nil
            fileContent = ""
            originalFileContent = ""
            fileSize = 0
            fileModificationDate = nil
            return
        }

        selectedFile = firstFile
        FileOperations.loadAndSetFileContent(
            file: firstFile,
            fileContent: $fileContent,
            originalFileContent: $originalFileContent,
            fileSize: $fileSize,
            fileModificationDate: $fileModificationDate
        )
    }

    private func saveGroupEditor() {
        guard let state = groupEditorState else {
            return
        }

        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        if let groupID = state.groupID {
            configManager.updateGroup(id: groupID, name: trimmedName)
        } else if let group = configManager.addGroup(name: trimmedName) {
            configManager.selectGroup(group.id)
        }

        groupEditorState = nil
    }

    private func scrollSelectedGroupIntoView(using proxy: ScrollViewProxy, animated: Bool = true) {
        let targetID = selectedGroupChipID
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            } else {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
    }

    private var selectedGroupChipID: String {
        configManager.selectedGroupID ?? "all-groups"
    }

    private func backgroundColor(isSelected: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.26)
        }
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        return Color.secondary.opacity(0.12)
    }

    private func borderColor(isSelected: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.72)
        }
        if isSelected {
            return Color.accentColor.opacity(0.4)
        }
        return Color.clear
    }

    private func shadowColor(isDragged: Bool, isDropTarget: Bool) -> Color {
        if isDragged {
            return Color.black.opacity(0.18)
        }
        if isDropTarget {
            return Color.accentColor.opacity(0.2)
        }
        return Color.clear
    }
}
