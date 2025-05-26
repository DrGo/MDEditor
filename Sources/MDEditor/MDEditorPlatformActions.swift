// Defines the protocol for platform-specific editor actions.
    
import Foundation

// Protocol definition for common editor actions that have platform-specific implementations.
// This allows MDEditorView to call these actions without needing #if os() checks at the call site.
@MainActor
protocol MDEditorPlatformActions {
    // Checks if an undo operation can be performed.
    func canUndo() -> Bool
    // Checks if a redo operation can be performed.
    func canRedo() -> Bool
    // Performs an undo operation.
    func undo()
    // Performs a redo operation.
    func redo()
    // Copies the provided text to the system pasteboard.
    func copyAll(text: String)
    // Potentially, methods for showing platform-specific font pickers could be added here later.
}
