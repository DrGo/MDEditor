// IOSEditorComponents.swift
// Contains iOS-specific UI components and platform action implementations for MDEditor.

#if os(iOS) // Entire file is iOS-specific

import SwiftUI
import UIKit

// MARK: - iOS Platform Actions Implementation
@MainActor
struct IOSPlatformActions: MDEditorPlatformActions {
    weak var textViewUndoManager: UndoManager?

    init(textViewUndoManager: UndoManager? = nil) {
        self.textViewUndoManager = textViewUndoManager
    }

    func canUndo() -> Bool {
        return textViewUndoManager?.canUndo ?? false // More accurate with direct UndoManager
    }

    func canRedo() -> Bool {
        return textViewUndoManager?.canRedo ?? false // More accurate
    }

    func undo() {
        if let manager = textViewUndoManager, manager.canUndo {
            manager.undo()
        } else {
            // Fallback if specific manager can't or isn't available
            // This might happen if the UITextView isn't first responder
            UIApplication.shared.sendAction(Selector(("undo:")), to: nil, from: nil, for: nil)
        }
    }

    func redo() {
        if let manager = textViewUndoManager, manager.canRedo {
            manager.redo()
        } else {
            UIApplication.shared.sendAction(Selector(("redo:")), to: nil, from: nil, for: nil)
        }
    }

    func copyAll(text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - iOS Font Picker (UIViewControllerRepresentable)
@MainActor
struct IOSFontPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedFont: UIFont?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let config = UIFontPickerViewController.Configuration()
        // config.includeFaces = true // Optionally include different font faces
        let picker = UIFontPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIFontPickerViewController, context: Context) {}

    @MainActor
    class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        let parent: IOSFontPickerRepresentable
        init(_ parent: IOSFontPickerRepresentable) { self.parent = parent }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            if let descriptor = viewController.selectedFontDescriptor {
                // We get the font name and size from the picker.
                // The size from the picker might not always be what we want for baseFontSize,
                // but it's a starting point. For MDEditor, we mainly use the name.
                self.parent.selectedFont = UIFont(descriptor: descriptor, size: descriptor.pointSize > 0 ? descriptor.pointSize : UIFont.systemFontSize)
            }
        }
        
        func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
            // No action needed for cancellation usually.
        }
    }
}

// MARK: - iOS Text Editor View (UIViewRepresentable for UITextView)
@MainActor
struct IOSEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var editorConfiguration: MDEditorConfiguration // Now a Binding
    var onUndoManagerAvailable: ((UndoManager?) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = false // For a plain text Markdown editor
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        
        // Provide the UndoManager as soon as the view is made
        DispatchQueue.main.async { // Ensure it's passed after setup
            onUndoManagerAvailable?(textView.undoManager)
        }
        
        applyConfiguration(to: textView, configuration: editorConfiguration, context: context)
        textView.text = text // Set initial text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text if changed externally
        if uiView.text != text {
            let selectedRange = uiView.selectedRange // Preserve selection
            uiView.text = text
            // Try to restore selection carefully
            if selectedRange.location <= (text as NSString).length {
                 uiView.selectedRange = selectedRange
            }
        }

        // Check if editorConfiguration (the value of the binding) has changed and re-apply if needed
        if context.coordinator.lastAppliedConfiguration != editorConfiguration {
            applyConfiguration(to: uiView, configuration: editorConfiguration, context: context)
            context.coordinator.lastAppliedConfiguration = editorConfiguration
        }
    }
    
    private func applyConfiguration(to textView: UITextView, configuration: MDEditorConfiguration, context: Context) {
        let font: UIFont
        if let fontName = configuration.editorFontName {
            font = UIFont(name: fontName, size: configuration.editorFontSize) ?? .systemFont(ofSize: configuration.editorFontSize)
        } else {
            font = .systemFont(ofSize: configuration.editorFontSize)
        }
        textView.font = font

        textView.backgroundColor = configuration.editorBackgroundColor
        textView.textColor = configuration.editorTextColor

        let paragraphStyle = (textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = configuration.editorLineSpacing
        
        // For indent width on UITextView, we manage tab stops.
        // This sets a single default tab stop. More complex tabbing requires more NSTextTab objects.
        let tabStop = NSTextTab(textAlignment: configuration.editorLayoutDirection == .rightToLeft ? .right : .left,
                                location: configuration.editorDefaultIndentWidth,
                                options: [:])
        paragraphStyle.tabStops = [tabStop]

        // Writing Direction & Alignment
        // For UITextView, textAlignment is key. semanticContentAttribute can also be used for deeper RTL support.
        if configuration.editorLayoutDirection == .rightToLeft {
            textView.textAlignment = .right
            // textView.semanticContentAttribute = .forceRightToLeft // If needed
        } else {
            textView.textAlignment = .left // Or .natural
            // textView.semanticContentAttribute = .forceLeftToRight // If needed
        }

        // Apply to typingAttributes to affect newly typed text
        var typingAttributes = textView.typingAttributes
        typingAttributes[.font] = font
        typingAttributes[.foregroundColor] = configuration.editorTextColor
        typingAttributes[.paragraphStyle] = paragraphStyle
        textView.typingAttributes = typingAttributes
        
        // If the entire existing text's alignment needs to be updated (e.g., on layoutDirection change)
        // This is a basic way; for full attributed string updates, one might iterate ranges.
        if textView.textAlignment != (configuration.editorLayoutDirection == .rightToLeft ? .right : .left) {
            textView.textAlignment = (configuration.editorLayoutDirection == .rightToLeft ? .right : .left)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSEditorTextView
        var lastAppliedConfiguration: MDEditorConfiguration?

        init(_ parent: IOSEditorTextView) {
            self.parent = parent
            self.lastAppliedConfiguration = parent.editorConfiguration // Initialize with current config
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // Ensure UndoManager is passed up when editing begins,
            // as it might be more reliably available then.
            parent.onUndoManagerAvailable?(textView.undoManager)
        }
    }
}

#endif // os(iOS)

