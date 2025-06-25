// MDEditorView.swift
// The main SwiftUI view for the Markdown editor.

import SwiftUI
import Markdown // From swift-markdown package

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
    @State private var themeLoadingError: String?

    private let initialTheme: MDEditorTheme

    #if os(macOS)
    @State private var nsTextView: NSTextView?
    #else // iOS (and other non-macOS Apple platforms if ever supported)
    @State private var iosTextViewUndoManager: UndoManager?
    #endif

    // Initializer
    public init(
        text: Binding<String>,
        initialMode: MDEditorMode = .view,
        initialTheme: MDEditorTheme = .internalDefault, // Assumes MDEditorTheme.internalDefault is available
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
    
    
    // A convenience initializer for AttributedString
      public init(
          attributedString: Binding<AttributedString>,
          initialMode: MDEditorMode = .view,
          initialTheme: MDEditorTheme = .internalDefault,
          editorConfiguration: Binding<MDEditorConfiguration>,
          themeURL: URL? = nil
      ) {
          // Create the proxy binding internally
          let stringBinding = Binding<String>(
              get: { String(attributedString.wrappedValue.characters) },
              set: { newStringValue in attributedString.wrappedValue = AttributedString(newStringValue) }
          )
          
          // Call the primary initializer with the proxy
          self.init(
              text: stringBinding,
              initialMode: initialMode,
              initialTheme: initialTheme,
              editorConfiguration: editorConfiguration,
              themeURL: themeURL
          )
      }

    
    // Platform-specific actions
    private func getPlatformActions() -> MDEditorPlatformActions {
        #if os(macOS)
        return MacOSPlatformActions(undoManager: self.nsTextView?.undoManager)
        #else // iOS
        return IOSPlatformActions(textViewUndoManager: self.iosTextViewUndoManager)
        #endif
    }

    // Editor content view builder
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
    
    // Theme loading and application logic
    private func loadAndApplyTheme(from url: URL?) {
        self.themeLoadingError = nil // Clear previous errors
        
        guard let themeFileURL = url else {
            // No URL provided, revert to initial theme if not already active
            if self.activeTheme.id != self.initialTheme.id {
                print("MDEditorView: No theme URL. Reverting to initialTheme: '\(self.initialTheme.frontMatter.title ?? "Untitled Initial Theme")'.")
                self.activeTheme = self.initialTheme
            }
            // Re-parse only if necessary (e.g., text changed while on initial theme, or attributedText is nil)
            if attributedText == nil || self.activeTheme.id == self.initialTheme.id {
                 parseAndUpdateAttributedString(markdown: text)
            }
            return
        }

        // Attempt to load the theme from the URL
        let result = ThemeLoader.loadTheme(from: themeFileURL) // Assumes ThemeLoader is available
        
        switch result {
        case .success(var loadedTheme):
            // Preserve current view's layout direction if theme doesn't specify one, or if different
            let currentViewLayoutDirection = self.activeTheme.layoutDirection
            if loadedTheme.layoutDirection == nil || (currentViewLayoutDirection != nil && currentViewLayoutDirection != loadedTheme.layoutDirection) {
                if currentViewLayoutDirection != nil { // Only override if current view had a specific one
                    loadedTheme.layoutDirection = currentViewLayoutDirection
                }
            }
            self.activeTheme = loadedTheme
            print("MDEditorView: Successfully loaded and applied theme '\(loadedTheme.frontMatter.title ?? "Untitled Loaded Theme")' from \(themeFileURL.lastPathComponent)")
            self.themeLoadingError = nil
        case .failure(let error):
            self.themeLoadingError = error.localizedDescription
            print("MDEditorView: ERROR loading/decoding theme: \(self.themeLoadingError ?? "Unknown error string")")
            // Revert to initial theme on error if not already active
            if self.activeTheme.id != self.initialTheme.id {
                 print("MDEditorView: Theme loading/decoding error. Reverting to initialTheme: '\(self.initialTheme.frontMatter.title ?? "Untitled Initial Theme")'.")
                self.activeTheme = self.initialTheme
            }
        }
        // Always re-parse after theme change attempt
        parseAndUpdateAttributedString(markdown: text)
    }

    // Computed properties for layout direction
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

    // Action to toggle layout direction
    private func toggleLayoutDirection() {
        if mode == .view {
            var newThemeToUpdateLayout = self.activeTheme
            newThemeToUpdateLayout.layoutDirection = (currentEffectiveLayoutDirection == .leftToRight) ? .rightToLeft : .leftToRight
            self.activeTheme = newThemeToUpdateLayout // This will trigger onChange for activeTheme
        } else {
            // This directly modifies the binding, host view should react if needed
            editorConfiguration.editorLayoutDirection = (currentEffectiveLayoutDirection == .leftToRight) ? .rightToLeft : .leftToRight
        }
    }

    // Main body of the view
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display theme loading errors
            if let error = themeLoadingError {
                ScrollView {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100) // Limit error view height
                Divider()
            }
            
            // Main content area
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
                } else { // View mode
                    ScrollView {
                        if let attributedText = attributedText {
                            Text(attributedText)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                .padding(10)
                                .textSelection(.enabled)
                        } else {
                            // Fallback for when attributedText is nil (e.g., during initial load or error)
                            Text(text) 
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                .padding(10)
                                .font(.system(.body, design: .monospaced)) // Basic monospaced display
                        }
                    }
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .environment(\.layoutDirection, (activeTheme.layoutDirection == .rightToLeft) ? .rightToLeft : .leftToRight)
                }
            }
        }
        .onChange(of: text) { oldValue, newText in
             parseAndUpdateAttributedString(markdown: newText)
        }
        .onChange(of: activeTheme) { oldValue, newTheme in
            print("MDEditorView: activeTheme CHANGED to '\(newTheme.frontMatter.title ?? "Untitled Theme")'. Clearing ALL cache and forcing re-render.")
            Self.renderingCache.removeAllObjects()
            parseAndUpdateAttributedString(markdown: text)
        }
        .onChange(of: editorConfiguration) { oldValue, newConfig in
            // This print statement is for debugging.
            // If editorConfiguration changes affect the raw text view directly (e.g., font size in edit mode),
            // the MacOSTextEditorView/IOSEditorTextView updateUIView methods should handle it.
            print("MDEditorView: editorConfiguration binding changed by host. LayoutDirection: \(newConfig.editorLayoutDirection)")
        }
        .onChange(of: themeURL) { oldValue, newURL in
            print("MDEditorView: themeURL CHANGED to \(newURL?.absoluteString ?? "nil"). Loading and applying.")
            loadAndApplyTheme(from: newURL)
        }
        .onAppear {
            if themeURL != nil {
                loadAndApplyTheme(from: themeURL)
            } else {
                // Ensure initial parsing if no theme URL and no attributedText yet
                if attributedText == nil {
                     parseAndUpdateAttributedString(markdown: text)
                }
            }
        }
        .toolbar {
            toolbarContent // Using the @ToolbarContentBuilder property
        }
    }

    // Toolbar content builder
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading items (Undo/Redo in Edit mode)
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
            // Placeholder for leading items in View mode if needed, or keep EmptyView
            ToolbarItemGroup(placement: toolbarItemPlacementLeading) {
                EmptyView()
            }
        }

        // Principal items (Mode Picker)
        ToolbarItemGroup(placement: .principal) {
            Picker("Mode", selection: $mode) {
                Text("View").tag(MDEditorMode.view)
                Text("Edit").tag(MDEditorMode.edit)
            }
            .pickerStyle(.segmented)
        }

        // Trailing items (Layout toggle, Clear, Copy All)
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

    // Helper computed properties for toolbar item placement
    // These must be at the struct's top level, not inside a function.
    private var toolbarItemPlacementLeading: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation // Standard for macOS leading items
        #else // iOS
        return .navigationBarLeading
        #endif
    }

    private var toolbarItemPlacementTrailing: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction // Standard for macOS primary actions
        #else // iOS
        return .navigationBarTrailing
        #endif
    }
    
    // Markdown parsing and AttributedString update logic
    // This must be a method of the struct.
    private func parseAndUpdateAttributedString(markdown: String) {
        // Use nil-coalescing for optional title in cacheKey for safety
        let cacheKey = "\(markdown)-\(activeTheme.id)-\(activeTheme.frontMatter.title ?? "no_title")-\(activeTheme.layoutDirection?.rawValue ?? "ltr")" as NSString
        
        if let cachedData = Self.renderingCache.object(forKey: cacheKey) {
            do {
                #if os(macOS)
                self.attributedText = try AttributedString(cachedData, including: \.appKit)
                #else // iOS
                self.attributedText = try AttributedString(cachedData, including: \.uiKit)
                #endif
            } catch {
                print("MDEditorView: Error converting cached NSAttributedString to AttributedString: \(error)")
                Self.renderingCache.removeObject(forKey: cacheKey) // Remove bad cache entry
                self.attributedText = AttributedString("Error displaying cached content.") // Fallback
            }
            return
        }
        
        // Perform parsing and rendering
        let document = Document(parsing: markdown)
        var renderer = MarkdownContentRenderer(theme: activeTheme) // Assumes MarkdownContentRenderer is available
        let nsAttributedString = renderer.attributedString(from: document)

        do {
            #if os(macOS)
            self.attributedText = try AttributedString(nsAttributedString, including: \.appKit)
            #else // iOS
            self.attributedText = try AttributedString(nsAttributedString, including: \.uiKit)
            #endif
        } catch {
            print("MDEditorView: Error converting new NSAttributedString to AttributedString: \(error)")
            self.attributedText = AttributedString("Error displaying content.") // Fallback
        }
        // Cache the newly rendered NSAttributedString
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
    // Uses .internalDefault which should be correctly defined in MDEditorTheme
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
