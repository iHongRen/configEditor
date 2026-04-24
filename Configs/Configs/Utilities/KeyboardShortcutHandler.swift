//
//  KeyboardShortcutHandler.swift
//  Configs
//
//  Created by cxy on 2025/7/7.
//

import SwiftUI
import AppKit

struct KeyboardShortcutHandler: ViewModifier {
    @Binding var showEditorSearchBar: Bool
    @Binding var editorSearchText: String
    @Binding var editorViewRef: CodeEditorView.Ref?
    @FocusState var searchFieldFocused: Bool
    @Binding var globalZoomLevel: Double
    @Binding var fileContent: String
    @Binding var originalFileContent: String
    @Binding var selectedFile: ConfigFile?
    @Binding var fileModificationDate: Date?
    @Binding var showHistorySidebar: Bool
    let selectPreviousFile: () -> Void
    let selectNextFile: () -> Void

    @State private var keyMonitor: Any?

    private func isEditorFirstResponder() -> Bool {
        // Our editor is a CustomTextView (subclass of NSTextView).
        // We only treat that as "editing config file".
        if NSApp.keyWindow?.firstResponder is CustomTextView {
            return true
        }
        return false
    }

    private func isTextInputFirstResponder() -> Bool {
        // NSTextView covers CodeEditorView and also the field editor used by many SwiftUI text inputs.
        if NSApp.keyWindow?.firstResponder is NSTextView {
            return true
        }
        return false
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command) {
                        if event.charactersIgnoringModifiers == "f" {
                            showEditorSearchBar = true
                            DispatchQueue.main.async {
                                searchFieldFocused = true
                            }
                            return nil
                        }
                        if event.charactersIgnoringModifiers == "s" {
                            if let file = selectedFile {
                                // Mark that this text change is from save operation
                                if let editorRef = editorViewRef, let coordinator = editorRef.coordinator {
                                    coordinator.isFromSave = true
                                }
                                
                                // Get cursor line content
                                let cursorLine = editorViewRef?.coordinator?.getCurrentLineContent()
                                
                                FileOperations.saveFileContentWithVersioning(
                                    file: file, 
                                    content: fileContent, 
                                    originalContent: originalFileContent, 
                                    cursorLine: cursorLine,
                                    onSaveSuccess: { modDate, newContent in
                                        fileModificationDate = modDate
                                        originalFileContent = newContent // Update original content after successful save
                                    }
                                )
                            }
                            return nil
                        }
                        if event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+" {
                            globalZoomLevel = min(2.0, globalZoomLevel + 0.1) // Max zoom 2.0
                            return nil
                        }
                        if event.charactersIgnoringModifiers == "-" {
                            globalZoomLevel = max(0.5, globalZoomLevel - 0.1) // Min zoom 0.5
                            return nil
                        }
                        if event.charactersIgnoringModifiers == "0" {
                            globalZoomLevel = 1.0 // Reset zoom
                            return nil
                        }
                    }
                    if event.keyCode == 53 { // 53 = esc
                        if showEditorSearchBar {
                            showEditorSearchBar = false
                            editorSearchText = ""
                            return nil
                        }
                    }
                    if event.keyCode == 36 || event.keyCode == 76 { // Enter or Return
                        if showEditorSearchBar {
                            editorViewRef?.findNext(editorSearchText)
                            return nil
                        }
                    }
                    if !event.modifierFlags.contains(.command) &&
                        !event.modifierFlags.contains(.option) &&
                        !event.modifierFlags.contains(.control) {
                        // When History is open and we're not actively editing the config file, Up/Down should
                        // navigate the commits list first (instead of switching files).
                        if showHistorySidebar && !isEditorFirstResponder() && !searchFieldFocused {
                            if let configPath = selectedFile?.path {
                                if event.keyCode == 126 { // Up arrow
                                    NotificationCenter.default.post(
                                        name: .historyNavigateCommit,
                                        object: nil,
                                        userInfo: ["configPath": configPath, "offset": -1]
                                    )
                                    return nil
                                }
                                if event.keyCode == 125 { // Down arrow
                                    NotificationCenter.default.post(
                                        name: .historyNavigateCommit,
                                        object: nil,
                                        userInfo: ["configPath": configPath, "offset": 1]
                                    )
                                    return nil
                                }
                            }
                        }

                        // When editing (or typing in any text input), arrow keys should stay in that control
                        // instead of switching the selected file in the sidebar.
                        if isTextInputFirstResponder() {
                            return event
                        }
                        if event.keyCode == 126 { // Up arrow
                            selectPreviousFile()
                            return nil
                        }
                        if event.keyCode == 125 { // Down arrow
                            selectNextFile()
                            return nil
                        }
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }
    }
}

extension View {
    func keyboardShortcutHandler(
        showEditorSearchBar: Binding<Bool>,
        editorSearchText: Binding<String>,
        editorViewRef: Binding<CodeEditorView.Ref?>,
        searchFieldFocused: FocusState<Bool>,
        globalZoomLevel: Binding<Double>,
        fileContent: Binding<String>,
        originalFileContent: Binding<String>,
        selectedFile: Binding<ConfigFile?>,
        fileModificationDate: Binding<Date?>,
        showHistorySidebar: Binding<Bool>,
        selectPreviousFile: @escaping () -> Void,
        selectNextFile: @escaping () -> Void
    ) -> some View {
        modifier(
            KeyboardShortcutHandler(
                showEditorSearchBar: showEditorSearchBar,
                editorSearchText: editorSearchText,
                editorViewRef: editorViewRef,
                searchFieldFocused: searchFieldFocused,
                globalZoomLevel: globalZoomLevel,
                fileContent: fileContent,
                originalFileContent: originalFileContent,
                selectedFile: selectedFile,
                fileModificationDate: fileModificationDate,
                showHistorySidebar: showHistorySidebar,
                selectPreviousFile: selectPreviousFile,
                selectNextFile: selectNextFile
            )
        )
    }
}
