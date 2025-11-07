//
//  SidebarView.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI


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

struct SidebarView: View {
    @ObservedObject var configManager: ConfigManager
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
    @State private var showTagSheet: Bool = false
    @State private var tagTextInput: String = ""
    @State private var tagR: Double = 200
    @State private var tagG: Double = 200
    @State private var tagB: Double = 200
    @State private var tagA: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ZStack {
                    TextField("Search config file...", text: $searchText, prompt: Text("Search config files..."))
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
                        .help("Add custom config file")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
            }

            List(selection: $selectedFile) {
                let filteredFiles = configManager.configFiles.filter { file in
                    searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText) || file.path.localizedCaseInsensitiveContains(searchText)
                }
                if filteredFiles.isEmpty {
                    Text("No config files found")
                        .font(.system(size: 13 * globalZoomLevel))
                } else {
                    ForEach(filteredFiles) { file in
                        HStack {
                            Text(file.name)
                                .font(.system(size: 13 * globalZoomLevel))
                            // Tag bubble display (capsule)
                            if let tag = file.tag {
                                let bg = Color(red: tag.r, green: tag.g, blue: tag.b).opacity(tag.a)
                                // 标签字体始终为白色
                                let fgColor: Color = .white
                                if tag.text.isEmpty {
                                    Circle()
                                        .fill(bg)
                                        .frame(width: 12, height: 12)
                                        .onTapGesture(count: 2) {
                                            // 双击圆形 tag 打开设置
                                            contextMenuFile = file
                                            tagTextInput = tag.text
                                            tagR = tag.r * 255.0
                                            tagG = tag.g * 255.0
                                            tagB = tag.b * 255.0
                                            tagA = tag.a
                                            showTagSheet = true
                                        }
                                } else {
                                    Text(tag.text)
                                        .font(.system(size: 10 * globalZoomLevel))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(bg)
                                        .foregroundColor(fgColor)
                                        .clipShape(Capsule())
                                        .onTapGesture(count: 2) {
                                        // 双击已设置的标签，打开标签设置弹窗
                                            contextMenuFile = file
                                            tagTextInput = tag.text
                                            tagR = tag.r * 255.0
                                            tagG = tag.g * 255.0
                                            tagB = tag.b * 255.0
                                            tagA = tag.a
                                            showTagSheet = true
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
                        .padding(.vertical, 4 * globalZoomLevel)
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
                                    Text(file.isPinned ? "Unpin" : "Pin")
                                }
                            }

                            // 打标签 - 放在第二个位置
                            Button(action: {
                                // prepare popover with existing values if any
                                contextMenuFile = file
                                if let tag = file.tag {
                                    tagTextInput = tag.text
                                    tagR = tag.r * 255.0
                                    tagG = tag.g * 255.0
                                    tagB = tag.b * 255.0
                                    tagA = tag.a
                                } else {
                                    tagTextInput = ""
                                    tagR = 200
                                    tagG = 200
                                    tagB = 200
                                    tagA = 1.0
                                }
                                showTagSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "tag")
                                    Text("打标签")
                                }
                            }

                            // 移除标签（仅当存在标签时显示）
                            if file.tag != nil {
                                Button(action: {
                                    configManager.setTag(nil, for: file)
                                }) {
                                    HStack {
                                        Image(systemName: "tag.slash")
                                        Text("移除标签")
                                    }
                                }
                            }

                            Divider()

                            Button(action: {
                                FileOperations.copyPathToClipboard(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Path")
                                }
                            }

                            Button(action: {
                                FileOperations.openInFinder(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Open in Finder")
                                }
                            }

                            Button(action: {
                                FileOperations.openInCode(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "highlighter")
                                    Text("Open in VSCode")
                                }
                            }

                            Button(action: {
                                FileOperations.openInCursor(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                    Text("Open in Cursor")
                                }
                            }

                            Button(action: {
                                FileOperations.openInTerminal(file.path)
                            }) {
                                HStack {
                                    Image(systemName: "terminal")
                                    Text("Open in Terminal")
                                }
                            }

                            Button(role: .destructive, action: {
                                contextMenuFile = file
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
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
                        let newConfig = ConfigFile(name: name, path: path, isCustom: true)
                        configManager.addConfigFile(newConfig)
                        selectedFile = newConfig
                        FileOperations.loadAndSetFileContent(file: newConfig, fileContent: $fileContent, originalFileContent: $originalFileContent, fileSize: $fileSize, fileModificationDate: $fileModificationDate)
                    }
                }
            default:
                break
            }
        }

        // Tagging sheet (original behavior) - improved layout
        .sheet(isPresented: $showTagSheet) {
            VStack(spacing: 16) {
                Text("给配置文件打标签")
                    .font(.headline)
                    .padding(.top, 16)

                // Input and preview on the same row
                HStack(spacing: 12) {
                    TextField("标签文本", text: $tagTextInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: tagTextInput) { _, new in
                            // 限制标签字数：中文 5 字，英文 10 字
                            let hasHan = new.range(of: "\\p{Han}", options: .regularExpression) != nil
                            let maxLen = hasHan ? 5 : 10
                            if new.count > maxLen {
                                tagTextInput = String(new.prefix(maxLen))
                            }
                        }

                    // Preview capsule
                    Text(tagTextInput.isEmpty ? "预览" : tagTextInput)
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: tagR/255.0, green: tagG/255.0, blue: tagB/255.0).opacity(tagA))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)

                // Quick colors under input
                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷颜色")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

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

                // Color sliders: each occupies a row; slider track shows the channel gradient based on current color
                VStack(alignment: .leading, spacing: 10) {
                    // compute dynamic gradient endpoints for each channel so the track reflects combined color
                    let start = Color(red: 1, green: 1, blue: 1)
                    let rEnd = Color(red: 1, green: 0, blue: 0)

                    HStack(alignment: .center) {
                        Text("R: \(Int(tagR))")
                            .frame(width: 52, alignment: .leading)
                        ZStack(alignment: .leading) {
                          
                            ColorSlider(value: $tagR, range: 0...255, gradient: LinearGradient(gradient: Gradient(colors: [start, rEnd]), startPoint: .leading, endPoint: .trailing))
                        }
                    }

                    let gEnd = Color(red: 0, green: 1, blue: 0)
                    HStack(alignment: .center) {
                        Text("G: \(Int(tagG))")
                            .frame(width: 52, alignment: .leading)
                        ZStack(alignment: .leading) {
                           
                            ColorSlider(value: $tagG, range: 0...255, gradient: LinearGradient(gradient: Gradient(colors: [start, gEnd]), startPoint: .leading, endPoint: .trailing))
                        }
                    }

                    let bEnd = Color(red: 0, green:0, blue: 1)
                    HStack(alignment: .center) {
                        Text("B: \(Int(tagB))")
                            .frame(width: 52, alignment: .leading)
                        ZStack(alignment: .leading) {
                         
                            ColorSlider(value: $tagB, range: 0...255, gradient: LinearGradient(gradient: Gradient(colors: [start, bEnd]), startPoint: .leading, endPoint: .trailing))
                        }
                    }

                    // Alpha row: keep label on the left, numeric value next, slider fills remaining space
                    HStack(alignment: .center) {
                     
                        Text(String(format: "A: %.2f", tagA))
                            .frame(width: 52, alignment: .leading)

                        ZStack(alignment: .leading) {
                            let curColor = Color(red: tagR/255.0, green: tagG/255.0, blue: tagB/255.0)
                            ColorSlider(value: $tagA, range: 0...1, gradient: LinearGradient(gradient: Gradient(colors: [curColor.opacity(0.1), curColor]), startPoint: .leading, endPoint: .trailing))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Actions: Delete (left) | Cancel | Save (right) - styled consistently
                HStack(spacing: 12) {
                    if let target = contextMenuFile, target.tag != nil {
                        Button(action: {
                            configManager.setTag(nil, for: target)
                            showTagSheet = false
                        }) {
                            Text("删除")
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    // Cancel (filled but subtle)
                    Button(action: { showTagSheet = false }) {
                        Text("取消")
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    }
                    .buttonStyle(PlainButtonStyle())


                    // Save (primary)
                    Button(action: {
                        guard let target = contextMenuFile else {
                            showTagSheet = false
                            return
                        }
                        let tag = FileTag(text: tagTextInput, r: (tagR/255.0), g: (tagG/255.0), b: (tagB/255.0), a: tagA)
                        configManager.setTag(tag, for: target)
                        showTagSheet = false
                    }) {
                        Text("保存")
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
            .frame(width: 250)
        }
    }
}

