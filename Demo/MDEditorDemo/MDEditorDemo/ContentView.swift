import SwiftUI
import MDEditor // Import your package library

struct ContentView: View {
    @State private var markdownText: String = """
    # Welcome to MDEditor!

    This demo now lets the host app choose a theme URL.
    MDEditorView will load the theme from that URL.

    ## Test Instructions:
    1. Ensure your theme YAML files are in the `CustomThemes` directory
       (e.g., in Application Support/YourAppName/CustomThemes/).
    2. Use the 'Select Theme' menu below to pick a theme.
    """

    private var initialViewStyle: MarkdownContentRenderer.StyleConfiguration {
        let style = MarkdownContentRenderer.StyleConfiguration(baseFontSize: 17.0)
        return style
    }

    @State private var editorConfig: MDEditorConfiguration = {
        #if os(iOS)
        return MDEditorConfiguration(editorFontSize: 17)
        #else
        return MDEditorConfiguration(editorFontSize: 14)
        #endif
    }()

    // Host app state for theme management
    @State private var availableThemeFileURLs: [URL] = []
    @State private var selectedThemeURL: URL? = nil // This will be passed to MDEditorView

    private var customThemesDirectoryURL: URL?

    init() {
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
                // Load available theme URLs on init
                self._availableThemeFileURLs = State(initialValue: loadThemeFileURLs(from: url))
                // Optionally set a default theme URL if desired
                // self._selectedThemeURL = State(initialValue: self.availableThemeFileURLs.first)
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
               .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) // Sort by filename
            print("ContentView: Found theme files: \(themeFileURLs.map { $0.lastPathComponent })")
            return themeFileURLs
        } catch {
            print("ContentView: Error loading theme file URLs from \(directoryURL.path): \(error)")
            return []
        }
    }
    
    // Helper to get a display name from a theme URL (filename without extension)
    private func themeName(from url: URL?) -> String {
        guard let url = url else { return "Default Style" }
        return url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        #if os(iOS)
        NavigationView {
            mainContent
                .navigationTitle("MDEditor Demo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        themeSelectionMenu()
                    }
                }
        }
        #else // macOS
        mainContent
            .frame(minWidth: 700, idealWidth: 800, maxWidth: .infinity, minHeight: 500, idealHeight: 700, maxHeight: .infinity)
            .toolbar { // Add theme selection to macOS window toolbar
                ToolbarItemGroup {
                    themeSelectionMenu()
                }
            }
        #endif
    }

    private var mainContent: some View {
        MDEditorView(
            text: $markdownText,
            initialMode: .view,
            initialStyleConfiguration: initialViewStyle, // Base style if no theme
            editorConfiguration: $editorConfig,
            themeURL: selectedThemeURL // Pass the selected theme URL
        )
    }

    @ViewBuilder
    private func themeSelectionMenu() -> some View {
        Menu {
            // Use a Picker to select the theme URL
            // The tag for the Picker needs to match the type of selectedThemeURL (URL?)
            Picker("Select Theme", selection: $selectedThemeURL.animation()) {
                Text("Default Style").tag(URL?.none) // Option for no theme (nil URL)
                ForEach(availableThemeFileURLs, id: \.self) { fileURL in
                    Text(themeName(from: fileURL)).tag(URL?(fileURL))
                }
            }
            .onChange(of: selectedThemeURL) { _, newURL in
                print("ContentView: Selected theme URL changed to: \(newURL?.lastPathComponent ?? "None")")
            }
            
            // Button to refresh the list of themes (if files are added/removed while app is running)
            Button("Refresh Theme List") {
                if let dirURL = customThemesDirectoryURL {
                    self.availableThemeFileURLs = loadThemeFileURLs(from: dirURL)
                    // If current selectedThemeURL is no longer valid, deselect it
                    if let currentSelected = selectedThemeURL, !self.availableThemeFileURLs.contains(currentSelected) {
                        self.selectedThemeURL = nil
                    }
                }
            }

        } label: {
            Label(themeName(from: selectedThemeURL), systemImage: "paintbrush")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
