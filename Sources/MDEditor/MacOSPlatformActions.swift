// MacOSEditorComponents.swift
// Contains macOS-specific UI components and platform action implementations for MDEditor.

#if os(macOS) // Entire file is macOS-specific

import SwiftUI
import AppKit

// MARK: - macOS Platform Actions Implementation
@MainActor
struct MacOSPlatformActions: MDEditorPlatformActions {
    private weak var undoManager: UndoManager?

    init(undoManager: UndoManager?) {
        self.undoManager = undoManager
    }

    func canUndo() -> Bool {
        return undoManager?.canUndo ?? false
    }

    func canRedo() -> Bool {
        return undoManager?.canRedo ?? false
    }

    func undo() {
        if undoManager?.canUndo ?? false {
            undoManager?.undo()
        } else {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        }
    }

    func redo() {
        if undoManager?.canRedo ?? false {
            undoManager?.redo()
        } else {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        }
    }

    func copyAll(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - macOS Text Editor View (NSViewRepresentable)
@MainActor
struct MacOSTextEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var nsTextView: NSTextView? // Provides the NSTextView instance back to MDEditorView
    @Binding var editorConfiguration: MDEditorConfiguration // Now a Binding

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Failed to get NSTextView from NSScrollView.")
        }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true // Enable the built-in undo manager

        applyConfiguration(to: textView, configuration: editorConfiguration, context: context)
        textView.string = text // Set initial text content

        DispatchQueue.main.async {
            self.nsTextView = textView // Pass the NSTextView instance out
        }
        
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false // Or true, based on preference
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Update text if it changed externally (e.g., binding modified by parent)
        if textView.string != text {
            let selectedRange = textView.selectedRange() // Preserve selection
            textView.string = text
            if selectedRange.location <= (text as NSString).length {
                 textView.setSelectedRange(selectedRange)
            }
        }
        
        // Check if editorConfiguration (the value of the binding) has changed.
        if context.coordinator.lastAppliedConfiguration != editorConfiguration {
            applyConfiguration(to: textView, configuration: editorConfiguration, context: context)
            context.coordinator.lastAppliedConfiguration = editorConfiguration
        }

        // Ensure the external nsTextView binding is current
        if self.nsTextView !== textView {
            DispatchQueue.main.async {
                self.nsTextView = textView
            }
        }
    }
    
    private func applyConfiguration(to textView: NSTextView, configuration: MDEditorConfiguration, context: Context) {
        let font: NSFont
        if let fontName = configuration.editorFontName {
            font = NSFont(name: fontName, size: configuration.editorFontSize) ?? .systemFont(ofSize: configuration.editorFontSize)
        } else {
            font = .systemFont(ofSize: configuration.editorFontSize)
        }
        textView.font = font

        textView.backgroundColor = configuration.editorBackgroundColor
        textView.textColor = configuration.editorTextColor

        let paragraphStyle = (textView.defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = configuration.editorLineSpacing
        paragraphStyle.defaultTabInterval = configuration.editorDefaultIndentWidth
        paragraphStyle.baseWritingDirection = (configuration.editorLayoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight
        if configuration.editorLayoutDirection == .rightToLeft {
            paragraphStyle.alignment = .right
        } else {
            paragraphStyle.alignment = .natural
        }
        textView.defaultParagraphStyle = paragraphStyle

        var typingAttributes = textView.typingAttributes
        typingAttributes[.font] = font
        typingAttributes[.foregroundColor] = configuration.editorTextColor
        typingAttributes[.paragraphStyle] = paragraphStyle
        textView.typingAttributes = typingAttributes
        
        if textView.alignment != paragraphStyle.alignment {
             textView.alignment = paragraphStyle.alignment
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacOSTextEditorView
        var lastAppliedConfiguration: MDEditorConfiguration?

        init(_ parent: MacOSTextEditorView) {
            self.parent = parent
            self.lastAppliedConfiguration = parent.editorConfiguration
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
        
        @objc func changeFont(_ sender: NSFontManager?) {
            guard let fontManager = sender, let textView = parent.nsTextView else { return }

            let newFont = fontManager.convert(textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize))
            
            // Update the binding, which will propagate to MDEditorView and the host app.
            parent.editorConfiguration.editorFontName = newFont.fontName
            parent.editorConfiguration.editorFontSize = newFont.pointSize
            
            // The updateNSView will be triggered by the change in editorConfiguration,
            // which will then call applyConfiguration to update the textView's font etc.
            print("Font Panel Changed Font. New Config: \(parent.editorConfiguration.editorFontName ?? "System") @ \(parent.editorConfiguration.editorFontSize)pt")
        }
    }
}

#endif // os(macOS)

