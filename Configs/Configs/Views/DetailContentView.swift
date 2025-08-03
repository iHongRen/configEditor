//
//  DetailContentView.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI


struct DetailContentView: View {
    @Binding var fileContent: String
    @Binding var selectedFile: ConfigFile?
    @Binding var editorSearchText: String
    @Binding var editorViewRef: CodeEditorView.Ref?
    @Binding var showEditorSearchBar: Bool
    @FocusState var searchFieldFocused: Bool
    @Binding var globalZoomLevel: Double
    @Binding var editorMatchCount: Int
    @Binding var editorCurrentMatchIndex: Int
    @Binding var fileSize: Int64
    @Binding var fileModificationDate: Date?
    @Binding var colorSchemeOption: ColorSchemeOption
    @Binding var showHistorySidebar: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showEditorSearchBar {
                HStack {
                    TextField("Search content...", text: $editorSearchText)
                        .frame(width: 200 * globalZoomLevel)
                        .disableAutocorrection(true)
                        .help("Search in current file (Press Enter for next)")
                        .focused($searchFieldFocused)
                        .font(.system(size: 13 * globalZoomLevel))
                        .onSubmit {
                            editorViewRef?.findNext(editorSearchText)
                        }
                        .onChange(of: editorSearchText) {
                            editorViewRef?.findNext(editorSearchText)
                        }
                    Button(action: {
                        editorViewRef?.findNext(editorSearchText)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13 * globalZoomLevel))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Find next")
                    Button(action: {
                        editorViewRef?.findPrevious(editorSearchText)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13 * globalZoomLevel))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Find previous")
                   
                    Text("\(editorCurrentMatchIndex) of \(editorMatchCount)")
                        .font(.system(size: 11 * globalZoomLevel))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showEditorSearchBar = false
                        editorSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13 * globalZoomLevel))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close search")
                }
                .padding(.all, 5 * globalZoomLevel)
            }
           
            CodeEditorView(text: $fileContent,
                       fileExtension: LanguageDetector.detectLanguage(selectedFile?.name),
                       search: $editorSearchText,
                       ref: $editorViewRef,
                       isFocused: !searchFieldFocused,
                       showSearchBar: {
                           showEditorSearchBar = true
                           DispatchQueue.main.async {
                               searchFieldFocused = true
                           }
                       },
                       onSave: {
                           if let file = selectedFile {
                               FileOperations.saveFileContent(file: file, content: fileContent) { newDate in
                                   self.fileModificationDate = newDate
                               }
                               VersionManager.shared.commit(content: fileContent, for: file.path)
                           }
                       },
                       zoomLevel: globalZoomLevel,
                       matchCount: $editorMatchCount,
                       currentMatchIndex: $editorCurrentMatchIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
           
            Divider()
            HStack(spacing: 8 * globalZoomLevel) {
                if let selectedFile = selectedFile {
                    Text(selectedFile.name)
                        .foregroundColor(.secondary)
                    Spacer()
                    if fileSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                    if let modDate = fileModificationDate {
                        Text("Modified \(modDate.formatModificationDate())")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.system(size: 11 * globalZoomLevel))
            .padding(.horizontal, 8 * globalZoomLevel)
            .padding(.vertical, 4 * globalZoomLevel)
            .frame(height: 24 * globalZoomLevel)
        }
        .frame(minWidth: 400 * globalZoomLevel)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if selectedFile != nil {
                        showHistorySidebar.toggle()
                    }
                }) {
                    Image(systemName: showHistorySidebar ? "clock.arrow.circlepath.fill" : "clock.arrow.circlepath")
                }
                .help(showHistorySidebar ? "Hide version history" : "Show version history")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Appearance", selection: $colorSchemeOption) {
                        ForEach(ColorSchemeOption.allCases, id: \.self) {
                            option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                } label: {
                    Image(systemName: colorSchemeOption == .dark ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(.accentColor)
                        .help("Change appearance")
                }
            }
        }
    }
}
