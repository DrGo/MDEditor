// ThemeManager.swift
// Manages loading and providing themes from YAML files,
// allowing for a custom themes directory specified by the host app.

import Foundation
import Yams // For YAML parsing

@MainActor
public class ThemeManager: ObservableObject {
    @Published public private(set) var themes: [MDEditorTheme] = []
    @Published public private(set) var errorMessages: [String] = []

    private let bundledThemesFolderName = "Themes" // Subdirectory in package's Resources
    private let customThemesURL: URL?

    /// Initializes the ThemeManager.
    /// - Parameter customThemesURL: An optional URL to a directory from which to load themes.
    ///   If nil, themes will be loaded from the package's bundled "Themes" resource directory.
    public init(customThemesURL: URL? = nil) {
        self.customThemesURL = customThemesURL
        loadThemes()
    }

    public func theme(named name: String) -> MDEditorTheme? {
        return themes.first(where: { $0.name == name })
    }

    public func loadThemes() {
        var loadedThemes: [MDEditorTheme] = []
        var currentErrors: [String] = []
        
        let themesDirectoryURLToLoadFrom: URL?

        if let customURL = customThemesURL {
            themesDirectoryURLToLoadFrom = customURL
            print("ThemeManager: Attempting to load themes from custom path: \(customURL.path)")
        } else {
            themesDirectoryURLToLoadFrom = Bundle.module.resourceURL?
                .appendingPathComponent(bundledThemesFolderName, isDirectory: true)
            print("ThemeManager: Attempting to load themes from bundled resources path: \(themesDirectoryURLToLoadFrom?.path ?? "Not found")")
        }

        guard let themesDirectoryURL = themesDirectoryURLToLoadFrom else {
            let errorMessage = "Error: Themes directory location could not be determined."
            print(errorMessage)
            currentErrors.append(errorMessage)
            self.errorMessages = currentErrors
            self.themes = []
            return
        }
        
        // Check if the determined directory exists
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: themesDirectoryURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            let errorMessage = "Error: Themes directory does not exist or is not a directory at path: \(themesDirectoryURL.path)."
            print(errorMessage)
            currentErrors.append(errorMessage)
            self.errorMessages = currentErrors
            self.themes = []
            return
        }


        do {
            let themeFileURLs = try fileManager.contentsOfDirectory(
                at: themesDirectoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }

            if themeFileURLs.isEmpty {
                let message = "No YAML theme files found in \(themesDirectoryURL.path)."
                print(message)
                // This is not an error, just an empty state.
            }

            for fileURL in themeFileURLs {
                do {
                    let yamlString = try String(contentsOf: fileURL, encoding: .utf8)
                    let decoder = YAMLDecoder()
                    let theme = try decoder.decode(MDEditorTheme.self, from: yamlString)
                    loadedThemes.append(theme)
                    print("Successfully loaded theme: \(theme.name) from \(fileURL.lastPathComponent)")
                } catch {
                    let errorMessage = "Error parsing theme from \(fileURL.lastPathComponent): \(error.localizedDescription)\nFull Error: \(error)"
                    print(errorMessage)
                    currentErrors.append(errorMessage)
                }
            }
        } catch {
            let errorMessage = "Error reading contents of Themes directory (\(themesDirectoryURL.path)): \(error.localizedDescription)"
            print(errorMessage)
            currentErrors.append(errorMessage)
        }
        
        self.themes = loadedThemes.sorted { $0.name.lowercased() < $1.name.lowercased() }
        self.errorMessages = currentErrors
    }
}
