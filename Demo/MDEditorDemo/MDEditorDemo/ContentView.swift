import SwiftUI
import MDEditor // Import your package library

struct ContentView: View {
    // State variable for the Markdown text, now initialized by loading from a resource
    @State private var markdownText: String = ""

    // The host app now provides an MDEditorTheme for initial styling.
    private var initialThemeForView: MDEditorTheme {
        var theme = MDEditorTheme.internalDefault
        theme.name = "Demo App Initial Theme"
        // theme.globalBaseFontSize = 14.0 // Example override
        return theme
    }

    // State variable for the Editor's configuration (Edit Mode).
    @State private var editorConfig: MDEditorConfiguration = {
        #if os(iOS)
        return MDEditorConfiguration(editorFontSize: 17)
        #else // macOS
        return MDEditorConfiguration(editorFontSize: 14)
        #endif
    }()

    // URL for the custom themes directory
    private var customThemesDirectoryURL: URL?
    
    @State private var selectedThemeURL: URL? = nil
    @State private var availableThemeFiles: [URL] = []

    // Function to load Markdown content from a bundled resource file
    private func loadMarkdownFromResource(named fileName: String, withExtension ext: String) -> String {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: ext) else {
            print("ContentView: Markdown resource file '\(fileName).\(ext)' not found.")
            return """
            # Error Loading Content
            
            Could not find the Markdown file named '\(fileName).\(ext)' in the app bundle.
            Please ensure it has been added to the MDEditorDemo target.
            """
        }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("ContentView: Error reading Markdown resource file '\(fileName).\(ext)': \(error)")
            return """
            # Error Reading File
            
            Failed to read content from '\(fileName).\(ext)'.
            Error: \(error.localizedDescription)
            """
        }
    }

    init() {
        // Initialize markdownText by loading from the resource
        // This assignment needs to happen before other UI elements might try to access it.
        // Since @State properties are initialized before 'self' is available,
        // we load it here and assign it.
        _markdownText = State(initialValue: loadMarkdownFromResource(named: "GFMShowcase", withExtension: "md"))

        let fileManager = FileManager.default
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "MDEditorDemoApp"
        var determinedURL: URL? = nil

        #if os(macOS)
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            determinedURL = appSupportURL.appendingPathComponent(appName).appendingPathComponent("CustomThemes")
        }
        #else // iOS
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            determinedURL = appSupportURL.appendingPathComponent(appName).appendingPathComponent("CustomThemes")
        }
        #endif
        
        self.customThemesDirectoryURL = determinedURL

        if let url = determinedURL {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                print("ContentView: Custom themes directory ensured at: \(url.path)")
                // Initialize State properties directly in init if they depend on instance members
                let initialThemeFiles = loadThemeFileURLs(from: url)
                _availableThemeFiles = State(initialValue: initialThemeFiles)
                // Optionally set a default theme from the custom directory
                // if initialThemeFiles.first != nil {
                //     _selectedThemeURL = State(initialValue: initialThemeFiles.first)
                // }
            } catch {
                print("ContentView: Error creating custom themes directory at \(url.path): \(error)")
            }
        } else {
            print("ContentView: Could not determine custom themes directory URL.")
        }
    }

    private func loadThemeFileURLs(from directoryURL: URL) -> [URL] {
        let fileManager = FileManager.default
        do {
            let themeFileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }
               .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            print("ContentView: Found theme files: \(themeFileURLs.map { $0.lastPathComponent })")
            return themeFileURLs
        } catch {
            print("ContentView: Error loading theme file URLs from \(directoryURL.path): \(error)")
            return []
        }
    }
    
    private func themeName(from url: URL?) -> String {
        guard let url = url else { return "Default (Initial Theme)" }
        return url.deletingPathExtension().lastPathComponent
    }


    var body: some View {
        #if os(iOS)
        NavigationView {
            mainEditorView
                .navigationTitle("MDEditor Demo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        themeSelectionMenu()
                    }
                }
        }
        #else // macOS
        mainEditorView
            .frame(minWidth: 700, idealWidth: 800, maxWidth: .infinity, minHeight: 500, idealHeight: 700, maxHeight: .infinity)
            .toolbar {
                ToolbarItemGroup {
                    themeSelectionMenu()
                }
            }
        #endif
    }

    private var mainEditorView: some View {
        MDEditorView(
            text: $markdownText,
            initialMode: .view,
            initialTheme: initialThemeForView,
            editorConfiguration: $editorConfig,
            themeURL: selectedThemeURL
        )
    }

    @ViewBuilder
    private func themeSelectionMenu() -> some View {
        Menu {
            Picker("Select Theme", selection: $selectedThemeURL.animation()) {
                Text("Default (Initial Theme)").tag(URL?.none)
                ForEach(availableThemeFiles, id: \.self) { fileURL in
                    Text(themeName(from: fileURL)).tag(URL?(fileURL))
                }
            }
            .onChange(of: selectedThemeURL) { _, newURL in
                print("ContentView: Host app selected theme URL: \(newURL?.lastPathComponent ?? "None (reverting to initial theme)")")
            }
            
            Button("Refresh Theme List") {
                if let dirURL = customThemesDirectoryURL {
                    self.availableThemeFiles = loadThemeFileURLs(from: dirURL)
                    if let currentSelected = selectedThemeURL, !self.availableThemeFiles.contains(currentSelected) {
                        self.selectedThemeURL = nil
                    }
                }
            }

        } label: {
            Label(themeName(from: selectedThemeURL), systemImage: "paintbrush")
                .labelStyle(.titleAndIcon)
        }
        .help("Select a theme for the Markdown viewer.")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


