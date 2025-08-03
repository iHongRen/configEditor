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

    @State private var keyMonitor: Any?

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
                                FileOperations.saveFileContentWithVersioning(file: file, content: fileContent, originalContent: originalFileContent) { modDate, newContent in
                                    fileModificationDate = modDate
                                    originalFileContent = newContent // Update original content after successful save
                                }
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
        fileModificationDate: Binding<Date?>
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
                fileModificationDate: fileModificationDate
            )
        )
    }
}
