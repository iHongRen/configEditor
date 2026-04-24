//
//  DetailContentView.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI
import Combine

extension View {
    @ViewBuilder
    func compatibleOnChange<V>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View where V: Equatable {
        if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) {
            self.onChange(of: value, initial: initial, action)
        } else {
            self
                .modifier(
                    ValueChangeModifier(
                        value: value,
                        initial: initial,
                        action: action
                    )
                )
        }
    }
    
    @ViewBuilder
    func compatibleOnChange<V>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View where V: Equatable {
        self.compatibleOnChange(of: value, initial: initial) { _, _ in
            action()
        }
    }
}

private struct ValueChangeModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    
    @State private var oldValue: V?
    
    func body(content: Content) -> some View {
        content
            .onReceive(Just(value)) { newValue in
                if let oldValue = oldValue {
                    if oldValue != newValue {
                        action(oldValue, newValue)
                        self.oldValue = newValue
                    }
                } else {
                    self.oldValue = newValue
                    if initial {
                        action(newValue, newValue)
                    }
                }
            }
    }
}

struct DetailContentView: View {
    @ObservedObject private var localization = LocalizationSettings.shared
    @Binding var fileContent: String
    @Binding var originalFileContent: String
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
    @Binding var showFileImporter: Bool
    var onFileDrop: (([URL]) -> Void)? = nil
    var onFileDragStateChanged: ((Bool) -> Void)? = nil
    var onEditorInteraction: (() -> Void)? = nil
    @State private var pathCopyToast: String? = nil
    @State private var pathCopyToastWorkItem: DispatchWorkItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let selectedFile {
                if showEditorSearchBar {
                    HStack {
                        TextField(L10n.tr("search.content.placeholder"), text: $editorSearchText)
                            .frame(width: 200 * globalZoomLevel)
                            .disableAutocorrection(true)
                            .help(L10n.tr("search.current.file.help"))
                            .focused($searchFieldFocused)
                            .font(.system(size: 13 * globalZoomLevel))
                            .onSubmit {
                                editorViewRef?.findNext(editorSearchText)
                            }
                            .compatibleOnChange(of: editorSearchText, {
                                editorViewRef?.findNext(editorSearchText)
                            })

                        Button(action: {
                            editorViewRef?.findNext(editorSearchText)
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13 * globalZoomLevel))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("find.next"))
                        Button(action: {
                            editorViewRef?.findPrevious(editorSearchText)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 13 * globalZoomLevel))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("find.previous"))

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
                        .help(L10n.tr("close.search"))
                    }
                    .padding(.all, 5 * globalZoomLevel)
                }

                CodeEditorView(text: $fileContent,
                           filePath: selectedFile.path,
                           fileExtension: LanguageDetector.detectLanguage(selectedFile.name),
                           search: $editorSearchText,
                           ref: $editorViewRef,
                           isFocused: !searchFieldFocused,
                           showSearchBar: {
                               showEditorSearchBar = true
                               DispatchQueue.main.async {
                                   searchFieldFocused = true
                               }
                           },

                           onSaveWithCursorLine: { cursorLine in
                               FileOperations.saveFileContentWithVersioning(
                                   file: selectedFile,
                                   content: fileContent,
                                   originalContent: originalFileContent,
                                   cursorLine: cursorLine,
                                   onSaveSuccess: { newDate, newContent in
                                       self.fileModificationDate = newDate
                                       self.originalFileContent = newContent
                                   }
                               )
                           },
                           onFileDrop: onFileDrop,
                           onFileDragStateChanged: onFileDragStateChanged,
                           onInteraction: onEditorInteraction,
                            estimatedFileSize: fileSize,
                           zoomLevel: globalZoomLevel,
                           matchCount: $editorMatchCount,
                           currentMatchIndex: $editorCurrentMatchIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                emptyPlaceholder
            }
           
            Divider()
            HStack(spacing: 8 * globalZoomLevel) {
                if let selectedFile = selectedFile {
                    Button(action: {
                        FileOperations.copyPathToClipboard(selectedFile.path)
                        showPathCopyToast()
                    }) {
                        Text(selectedFile.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("copy.path"))
                    if let pathCopyToast {
                        Text(pathCopyToast)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                    Spacer()
                    if fileSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                    if let modDate = fileModificationDate {
                        Text(L10n.tr("modified.at", modDate.formatModificationDate()))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.system(size: 11 * globalZoomLevel))
            .padding(.horizontal, 8 * globalZoomLevel)
            .padding(.vertical, 4 * globalZoomLevel)
            .frame(height: 24 * globalZoomLevel)
        }
        .onDisappear {
            pathCopyToastWorkItem?.cancel()
            pathCopyToastWorkItem = nil
        }
        .frame(minWidth: 400 * globalZoomLevel)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if selectedFile != nil {
                        showHistorySidebar.toggle()
                    }
                }) {
                    Image(systemName: showHistorySidebar ? "clock.fill" : "clock")
                }
                .help(showHistorySidebar ? L10n.tr("hide.version.history") : L10n.tr("show.version.history"))
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(L10n.tr("appearance"), selection: $colorSchemeOption) {
                        ForEach(ColorSchemeOption.allCases, id: \.self) {
                            option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                } label: {
                    Image(systemName: colorSchemeOption == .dark ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(.accentColor)
                        .help(L10n.tr("change.appearance"))
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 18 * globalZoomLevel) {
            ZStack {
                RoundedRectangle(cornerRadius: 24 * globalZoomLevel, style: .continuous)
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
                    .frame(width: 130 * globalZoomLevel, height: 130 * globalZoomLevel)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48 * globalZoomLevel, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8 * globalZoomLevel) {
                Text(L10n.tr("empty.group.title"))
                    .font(.system(size: 22 * globalZoomLevel, weight: .semibold))

                Text(L10n.tr("empty.group.description"))
                    .font(.system(size: 13 * globalZoomLevel))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32 * globalZoomLevel)
        .contentShape(Rectangle())
        .onTapGesture {
            showFileImporter = true
        }
    }

    private func showPathCopyToast() {
        pathCopyToastWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.16)) {
            pathCopyToast = L10n.tr("copy.path.copied")
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                pathCopyToast = nil
            }
        }
        pathCopyToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
}
