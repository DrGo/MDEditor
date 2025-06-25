// ThemeLoader.swift
// Loads theme file content and uses ThemeParser to decode it.

import Foundation
import SwiftUI // For MDEditorTheme (indirectly via ThemeParser)

// YamlParsingError is now defined in YamlParser.swift and public

public class ThemeLoader {
    public static func loadTheme(from url: URL) -> Result<MDEditorTheme, Error> {
        let fileContents: String
        do {
            fileContents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Return the specific YamlParsingError case for file reading issues
            return .failure(YamlParsingError.fileReadError(url, error)) 
        }

        do {
            let theme = try ThemeParser.parse(themeFileContents: fileContents)
            return .success(theme)
        } catch let parsingError as YamlParsingError { // Catch specific YamlParsingError
            return .failure(parsingError)
        } catch {
            // Catch any other unexpected errors from ThemeParser.parse
            // and wrap them in a generic YamlParsingError for consistency
            print("ThemeLoader: Unexpected error type from ThemeParser.parse: \(error)")
            return .failure(YamlParsingError.syntaxError(line: 0, message: "An unexpected error occurred during theme parsing: \(error.localizedDescription)"))
        }
    }
}
