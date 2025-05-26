// MDEditorView.swift
// The main SwiftUI view for the Markdown editor.

import SwiftUI
import Markdown // From swift-markdown package
import Yams // For parsing the theme YAML file

public enum MDEditorMode {
    case view
    case edit
}

public struct MDEditorView: View {
    @Binding private var text: String
    @State private var mode: MDEditorMode
    @State private var attributedText: AttributedString?
    
    @State private var currentStyleConfiguration: MarkdownContentRenderer.StyleConfiguration
    @Binding private var editorConfiguration: MDEditorConfiguration
    
    private static var renderingCache = NSCache<NSString, NSAttributedString>()

    // Theme URL provided by the host app
    private let themeURL: URL?
    @State private var themeLoadingError: String? // To display errors if theme loading fails

    #if os(macOS)
    @State private var nsTextView: NSTextView?
    #else // iOS
    @State private var iosTextViewUndoManager: UndoManager?
    #endif

    #if os(iOS)
    @State private var showingIOSFontPicker = false
    @State private var selectedIOSFont: UIFont?
    #endif

    // Store the initial style configuration to revert to if no theme is applied or theme loading fails
    private let initialStyleConfiguration: MarkdownContentRenderer.StyleConfiguration

    public init(
        text: Binding<String>,
        initialMode: MDEditorMode = .view,
        initialStyleConfiguration: MarkdownContentRenderer.StyleConfiguration = .init(), // Base style
        editorConfiguration: Binding<MDEditorConfiguration>,
        themeURL: URL? = nil // URL of the theme file to apply
    ) {
        self._text = text
        self._mode = State(initialValue: initialMode)
        self.initialStyleConfiguration = initialStyleConfiguration
        self._currentStyleConfiguration = State(initialValue: initialStyleConfiguration) // Start with initial
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
        #endif
    }
    
    private func loadAndApplyTheme(from url: URL?) {
        self.themeLoadingError = nil // Clear previous errors
        guard let themeFileURL = url else {
            // No theme URL provided, apply the initial base style configuration
            self.currentStyleConfiguration = self.initialStyleConfiguration
            print("MDEditorView: No theme URL provided. Applying initial style configuration.")
            return
        }

        do {
            let yamlString = try String(contentsOf: themeFileURL, encoding: .utf8)
            let decoder = YAMLDecoder()
            let loadedTheme = try decoder.decode(MDEditorTheme.self, from: yamlString)
            
            let currentLayoutDirection = self.currentStyleConfiguration.layoutDirection // Preserve
            var newConfig = loadedTheme.toStyleConfiguration(baseDefaults: self.initialStyleConfiguration)
            newConfig.layoutDirection = currentLayoutDirection
            
            self.currentStyleConfiguration = newConfig
            print("MDEditorView: Successfully loaded and applied theme from \(themeFileURL.lastPathComponent)")
        } catch {
            self.themeLoadingError = "Failed to load theme from \(themeFileURL.lastPathComponent): \(error.localizedDescription)"
            print("MDEditorView: \(themeLoadingError!)")
            // Fallback to initial style configuration on error
            self.currentStyleConfiguration = self.initialStyleConfiguration
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = themeLoadingError { // Display theme loading error
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            Group {
                if mode == .edit {
                    editorContentView()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                        .padding(5)
                        #if os(macOS)
                        .border(Color(NSColor.separatorColor), width: 0.5)
                        #else
                        .border(Color(UIColor.separator), width: 0.5)
                        #endif
                } else { // View Mode
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
                    .environment(\.layoutDirection, currentStyleConfiguration.layoutDirection)
                }
            }
        }
        .onChange(of: text) { _, newText in
             parseAndUpdateAttributedString(markdown: newText)
        }
        .onChange(of: currentStyleConfiguration) { // When style changes (e.g., due to theme or manual font change)
            forceReRender()
        }
        .onChange(of: editorConfiguration) { _, newConfig in
            print("MDEditorView: editorConfiguration binding changed. Font: \(newConfig.editorFontName ?? "System") @ \(newConfig.editorFontSize)pt")
        }
        .onChange(of: themeURL) { _, newURL in // When host provides a new theme URL
            loadAndApplyTheme(from: newURL)
        }
        #if os(iOS)
        .onChange(of: selectedIOSFont) { _, newFont in
            if let font = newFont {
                // Manual font change for View Mode. This overrides the current theme's font.
                // The themeURL is not changed, so if it's re-applied, this manual change is lost.
                currentStyleConfiguration.baseFontName = font.fontName
                currentStyleConfiguration.baseFontSize = font.pointSize
                // No longer managing selectedThemeName internally
            }
        }
        #endif
        .onAppear {
            // Load initial theme if URL is provided at init
            loadAndApplyTheme(from: themeURL)
            parseAndUpdateAttributedString(markdown: text)
        }
        .toolbar { // Toolbar is simplified as theme selection is now host's responsibility
            ToolbarItemGroup(placement: toolbarItemPlacementLeading) {
                if mode == .edit {
                    Button { getPlatformActions().undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .help("Undo")
                        .disabled(!getPlatformActions().canUndo())

                    Button { getPlatformActions().redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .help("Redo")
                        .disabled(!getPlatformActions().canRedo())
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
                Button { // Layout direction for View Mode
                    currentStyleConfiguration.layoutDirection = (currentStyleConfiguration.layoutDirection == .leftToRight) ? .rightToLeft : .leftToRight
                } label: {
                    Image(systemName: currentStyleConfiguration.layoutDirection == .leftToRight ? "text.alignright" : "text.alignleft")
                }
                .help(currentStyleConfiguration.layoutDirection == .leftToRight ? "Switch View to Right-to-Left" : "Switch View to Left-to-Right")

                Menu { // "Formatting Options" Menu
                    // Button to choose font for View Mode (manual override)
                    Button("Choose Font (View Mode)...") {
                        #if os(iOS)
                        showingIOSFontPicker = true
                        #elseif os(macOS)
                        NSFontManager.shared.target = nil
                        NSFontManager.shared.orderFrontFontPanel(nil)
                        #endif
                    }
                    
                    #if os(macOS) // Button to choose font for Edit Mode
                    if mode == .edit {
                        Button("Choose Font (Edit Mode)...") {
                            if let textView = nsTextView, textView.window?.firstResponder == textView {
                                NSFontManager.shared.target = textView
                                NSFontManager.shared.orderFrontFontPanel(nil)
                            } else {
                                NSApp.sendAction(#selector(NSFontManager.orderFrontFontPanel(_:)), to: NSFontManager.shared, from: nil)
                            }
                        }
                    }
                    #endif
                    // Theme picker is removed from here. Host app provides it.
                } label: { Image(systemName: "textformat.size") }
                .help("Formatting Options")
                
                Button { text = "" } label: { Image(systemName: "trash") }
                    .help("Clear Editor")
                
                Button { getPlatformActions().copyAll(text: text) } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy All (copies raw Markdown)")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingIOSFontPicker) {
            IOSFontPickerRepresentable(selectedFont: $selectedIOSFont)
                .ignoresSafeArea()
        }
        #endif
    }

    private var toolbarItemPlacementLeading: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation
        #else
        return .navigationBarLeading
        #endif
    }

    private var toolbarItemPlacementTrailing: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else
        return .navigationBarTrailing
        #endif
    }
    
    private func forceReRender() {
        Self.renderingCache.removeObject(forKey: text as NSString)
        parseAndUpdateAttributedString(markdown: text)
    }
    
    private func parseAndUpdateAttributedString(markdown: String) {
        let cacheKey = markdown as NSString
        if let cachedData = Self.renderingCache.object(forKey: cacheKey) {
            do {
                self.attributedText = try AttributedString(cachedData, including: \.swiftUI)
            } catch {
                print("Error converting cached NSAttributedString to AttributedString: \(error)")
                self.attributedText = AttributedString(markdown)
            }
            return
        }
        
        let document = Document(parsing: markdown)
        var renderer = MarkdownContentRenderer(configuration: currentStyleConfiguration)
        let nsAttributedString = renderer.attributedString(from: document)

        do {
            self.attributedText = try AttributedString(nsAttributedString, including: \.swiftUI)
        } catch {
            print("Error converting new NSAttributedString to AttributedString: \(error)")
            self.attributedText = AttributedString(markdown)
        }
        Self.renderingCache.setObject(nsAttributedString, forKey: cacheKey)
    }
}

// MARK: - Preview
#if DEBUG
struct MDEditorView_Previews: PreviewProvider {
    @State static var markdownText: String = "Preview Text"
    @State static var previewEditorConfig: MDEditorConfiguration = .init()
    static let previewInitialStyle: MarkdownContentRenderer.StyleConfiguration = .init(baseFontSize: 15)
    // For previewing with a theme URL, you'd need a sample theme file accessible by the preview.
    // This is harder to set up directly in previews for package resources or custom file paths.
    // You could create a dummy URL pointing to a test YAML string for preview purposes if needed.
    // static let previewThemeURL: URL? = nil

    static var previews: some View {
        #if os(macOS)
        MDEditorView(
            text: $markdownText,
            initialStyleConfiguration: previewInitialStyle,
            editorConfiguration: $previewEditorConfig
            // themeURL: previewThemeURL // Pass a theme URL for preview if available
        )
        .navigationTitle("MDEditor (macOS)")
        .frame(width: 550, height: 750)
        .previewDisplayName("MDEditor macOS Preview")
        #else // iOS and other platforms
        NavigationView {
            MDEditorView(
                text: $markdownText,
                initialStyleConfiguration: previewInitialStyle,
                editorConfiguration: $previewEditorConfig
                // themeURL: previewThemeURL
            )
            .navigationTitle("MDEditor (iOS)")
        }
        .previewDisplayName("MDEditor iOS Preview")
        .previewInterfaceOrientation(.portrait)
        #endif
    }
}
#endif
