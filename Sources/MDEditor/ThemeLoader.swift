// ThemeLoader.swift
// Loads theme file content and uses ThemeParser to decode it.

import Foundation
import SwiftUI // For MDEditorTheme (indirectly via ThemeParser)

// ThemeParsingError is now defined in ThemeParser.swift

public class ThemeLoader {
    public static func loadTheme(from url: URL) -> Result<MDEditorTheme, ThemeParsingError> {
        let fileContents: String
        do {
            fileContents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Use the ThemeParsingError for file read issues as well for consistency
            return .failure(.fileReadError(url, error))
        }

        do {
            let theme = try ThemeParser.parse(themeFileContents: fileContents)
            return .success(theme)
        } catch let parsingError as ThemeParsingError {
            // If ThemeParser.parse throws a ThemeParsingError, propagate it
            return .failure(parsingError)
        } catch {
            // Catch any other unexpected errors from ThemeParser.parse
            // and wrap them in a generic ThemeParsingError
            print("ThemeLoader: Unexpected error type from ThemeParser.parse: \(error)")
            return .failure(.syntaxError(line: 0, message: "An unexpected error occurred during theme parsing: \(error.localizedDescription)"))
        }
    }
}
