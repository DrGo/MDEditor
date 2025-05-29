// MDEditorView.swift
// The main SwiftUI view for the Markdown editor.

import SwiftUI
import Markdown // From swift-markdown package
// Yams is now used by ThemeLoader

// TextDirection enum is expected to be defined in TextDirection.swift
// MDEditorTheme is expected to be defined in MDEditorTheme.swift
// MDEditorConfiguration is expected to be defined in MDEditorConfiguration.swift
// ThemeLoader is expected to be defined in ThemeLoader.swift

public enum MDEditorMode {
    case view
    case edit
}

public struct MDEditorView: View {
    @Binding private var text: String
    @State private var mode: MDEditorMode
    @State private var attributedText: AttributedString?
    
    @State private var activeTheme: MDEditorTheme
    @Binding private var editorConfiguration: MDEditorConfiguration
    
    private static var renderingCache = NSCache<NSString, NSAttributedString>()

    private let themeURL: URL?
    @State private var themeLoadingError: String? // Will store the localized description of ThemeLoadingError

    private let initialTheme: MDEditorTheme

    #if os(macOS)
    @State private var nsTextView: NSTextView?
    #else // iOS (and other non-macOS Apple platforms if ever supported)
    @State private var iosTextViewUndoManager: UndoManager?
    #endif

    public init(
        text: Binding<String>,
        initialMode: MDEditorMode = .view,
        initialTheme: MDEditorTheme = .internalDefault,
        editorConfiguration: Binding<MDEditorConfiguration>,
        themeURL: URL? = nil
    ) {
        self._text = text
        self._mode = State(initialValue: initialMode)
        self.initialTheme = initialTheme
        self._activeTheme = State(initialValue: initialTheme) // Initialize with initialTheme
        self._editorConfiguration = editorConfiguration
        self.themeURL = themeURL
    }
    
    private func getPlatformActions() -> MDEditorPlatformActions {
        #if os(macOS)
        return MacOSPlatformActions(undoManager: self.nsTextView?.undoManager)
        #else // iOS
        return IOSPlatformActions(textViewUndoManager: self.iosTextViewUndoManager)
        #endif
    }

    @ViewBuilder
    private func editorContentView() -> some View {
        #if os(macOS)
        MacOSTextEditorView(
            text: $text,
            nsTextView: $nsTextView,
            editorConfiguration: $editorConfiguration
        )
        #else // iOS
        IOSEditorTextView(
            text: $text,
            editorConfiguration: $editorConfiguration,
            onUndoManagerAvailable: { undoManager in
                self.iosTextViewUndoManager = undoManager
            }
        )
        .environment(\.layoutDirection, editorConfiguration.swiftUILayoutDirection)
        #endif
    }
    
    private func loadAndApplyTheme(from url: URL?) {
        self.themeLoadingError = nil
        
        guard let themeFileURL = url else {
            if self.activeTheme.id != self.initialTheme.id {
                print("MDEditorView: No theme URL. Reverting to initialTheme: '\(self.initialTheme.name)'.")
                self.activeTheme = self.initialTheme
            }
            if attributedText == nil || self.activeTheme.id == self.initialTheme.id {
                 parseAndUpdateAttributedString(markdown: text)
            }
            return
        }

        let result = ThemeLoader.loadTheme(from: themeFileURL)
        
        switch result {
        case .success(var loadedTheme):
            let currentViewLayoutDirection = self.activeTheme.layoutDirection
            if currentViewLayoutDirection != nil && currentViewLayoutDirection != loadedTheme.layoutDirection {
                loadedTheme.layoutDirection = currentViewLayoutDirection
            }
            self.activeTheme = loadedTheme
            print("MDEditorView: Successfully loaded and applied theme '\(loadedTheme.name)' from \(themeFileURL.lastPathComponent)")
            self.themeLoadingError = nil
        case .failure(let error):
            self.themeLoadingError = error.localizedDescription // Using the localizedDescription from ThemeLoadingError
            print("MDEditorView: ERROR loading/decoding theme: \(self.themeLoadingError ?? "Unknown error string")")
            if self.activeTheme.id != self.initialTheme.id {
                 print("MDEditorView: Theme loading/decoding error. Reverting to initialTheme: '\(self.initialTheme.name)'.")
                self.activeTheme = self.initialTheme
            }
        }
        parseAndUpdateAttributedString(markdown: text)
    }

    // MARK: - Computed Properties and Methods for LTR/RTL Toggle
    private var currentEffectiveLayoutDirection: TextDirection {
        if mode == .view {
            return activeTheme.layoutDirection ?? .leftToRight
        } else {
            return editorConfiguration.editorLayoutDirection
        }
    }

    private var currentSwiftUILayoutDirection: SwiftUI.LayoutDirection {
        return currentEffectiveLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    private func toggleLayoutDirection() {
        if mode == .view {
            var newThemeToUpdateLayout = self.activeTheme
            newThemeToUpdateLayout.layoutDirection = (currentEffectiveLayoutDirection == .leftToRight) ? .rightToLeft : .leftToRight
            self.activeTheme = newThemeToUpdateLayout
        } else {
            editorConfiguration.editorLayoutDirection = (currentEffectiveLayoutDirection == .leftToRight) ? .rightToLeft : .leftToRight
        }
    }


    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = themeLoadingError {
                ScrollView { // Make error scrollable if it's long
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading) // Ensure it takes width
                }
                .frame(maxHeight: 100) // Limit height of error view
                Divider()
            }
            Group {
                if mode == .edit {
                    editorContentView()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                        .padding(5)
                        #if os(macOS)
                        .border(Color(NSColor.separatorColor), width: 0.5)
                        #else // iOS
                        .border(Color(UIColor.separator), width: 0.5)
                        #endif
                } else {
                    ScrollView {
                        if let attributedText = attributedText {
                            Text(attributedText)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                .padding(10)
                                .textSelection(.enabled)
                        } else {
                            Text(text)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                .padding(10)
                        }
                    }
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .environment(\.layoutDirection, (activeTheme.layoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight)
                }
            }
        }
        .onChange(of: text) { _, newText in
             parseAndUpdateAttributedString(markdown: newText)
        }
        .onChange(of: activeTheme) { _, newTheme in
            print("MDEditorView: activeTheme CHANGED to '\(newTheme.name)'. Clearing ALL cache and forcing re-render.")
            Self.renderingCache.removeAllObjects()
            parseAndUpdateAttributedString(markdown: text)
        }
        .onChange(of: editorConfiguration) { _, newConfig in
            print("MDEditorView: editorConfiguration binding changed by host. LayoutDirection: \(newConfig.editorLayoutDirection)")
        }
        .onChange(of: themeURL) { _, newURL in
            print("MDEditorView: themeURL CHANGED to \(newURL?.absoluteString ?? "nil"). Loading and applying.")
            loadAndApplyTheme(from: newURL)
        }
        .onAppear {
            if themeURL != nil {
                loadAndApplyTheme(from: themeURL)
            } else {
                if attributedText == nil {
                     parseAndUpdateAttributedString(markdown: text)
                }
            }
        }
        .toolbar {
            toolbarContent
        }
    }

    // MARK: - Consolidated Toolbar Content Builder
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if mode == .edit {
            ToolbarItemGroup(placement: toolbarItemPlacementLeading) {
                Button { getPlatformActions().undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .help("Undo")
                    .disabled(!getPlatformActions().canUndo())

                Button { getPlatformActions().redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .help("Redo")
                    .disabled(!getPlatformActions().canRedo())
            }
        } else {
            ToolbarItemGroup(placement: toolbarItemPlacementLeading) {
                EmptyView()
            }
        }

        ToolbarItemGroup(placement: .principal) {
            Picker("Mode", selection: $mode) {
                Text("View").tag(MDEditorMode.view)
                Text("Edit").tag(MDEditorMode.edit)
            }
            .pickerStyle(.segmented)
        }

        ToolbarItemGroup(placement: toolbarItemPlacementTrailing) {
            Button {
                toggleLayoutDirection()
            } label: {
                Image(systemName: currentSwiftUILayoutDirection == .leftToRight ? "text.alignright" : "text.alignleft")
            }
            .help("Toggle Layout Direction (LTR/RTL)")
                            
            Button { text = "" } label: { Image(systemName: "trash") }
                .help("Clear Editor")
            
            Button { getPlatformActions().copyAll(text: text) } label: { Image(systemName: "doc.on.doc") }
                .help("Copy All (copies raw Markdown)")
        }
    }


    // MARK: - Helper Properties and Methods
    private var toolbarItemPlacementLeading: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation
        #else // iOS
        return .navigationBarLeading
        #endif
    }

    private var toolbarItemPlacementTrailing: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else // iOS
        return .navigationBarTrailing
        #endif
    }
    
    private func parseAndUpdateAttributedString(markdown: String) {
        let cacheKey = "\(markdown)-\(activeTheme.id)-\(activeTheme.layoutDirection?.rawValue ?? "ltr")" as NSString
        
        if let cachedData = Self.renderingCache.object(forKey: cacheKey) {
            do {
                #if os(macOS)
                self.attributedText = try AttributedString(cachedData, including: \.appKit)
                #else // iOS
                self.attributedText = try AttributedString(cachedData, including: \.uiKit)
                #endif
            } catch {
                print("MDEditorView: Error converting cached NSAttributedString to AttributedString: \(error)")
                Self.renderingCache.removeObject(forKey: cacheKey)
                self.attributedText = AttributedString("Error displaying cached content.")
            }
            return
        }
        
        let document = Document(parsing: markdown)
        var renderer = MarkdownContentRenderer(theme: activeTheme)
        let nsAttributedString = renderer.attributedString(from: document)

        do {
            #if os(macOS)
            self.attributedText = try AttributedString(nsAttributedString, including: \.appKit)
            #else // iOS
            self.attributedText = try AttributedString(nsAttributedString, including: \.uiKit)
            #endif
        } catch {
            print("MDEditorView: Error converting new NSAttributedString to AttributedString: \(error)")
            self.attributedText = AttributedString("Error displaying content.")
        }
        Self.renderingCache.setObject(nsAttributedString, forKey: cacheKey)
    }
}

// MARK: - Preview
#if DEBUG
struct MDEditorView_Previews: PreviewProvider {
    @State static var markdownText: String = """
    # Preview
    This is **preview** text with a [link](https://example.com).
    - Item 1
    - Item 2
    """
    @State static var previewEditorConfig: MDEditorConfiguration = .init()
    static let previewInitialTheme: MDEditorTheme = .internalDefault
    
    static var previews: some View {
        #if os(macOS)
        MDEditorView(
            text: $markdownText,
            initialTheme: previewInitialTheme,
            editorConfiguration: $previewEditorConfig
        )
        .navigationTitle("MDEditor (macOS)")
        .frame(width: 550, height: 750)
        .previewDisplayName("MDEditor macOS Preview")
        #else // iOS
        NavigationView {
            MDEditorView(
                text: $markdownText,
                initialTheme: previewInitialTheme,
                editorConfiguration: $previewEditorConfig
            )
            .navigationTitle("MDEditor (iOS)")
        }
        .previewDisplayName("MDEditor iOS Preview")
        .previewInterfaceOrientation(.portrait)
        #endif
    }
}
#endif

