import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var store: NoteStore
    @Binding var searchFocusRequest: Int
    @Binding var editorFocusRequest: Int

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                store.createNote()
                editorFocusRequest += 1
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Note") {
            Button("Search Notes") { searchFocusRequest += 1 }
                .keyboardShortcut("f", modifiers: .command)
            Button("Focus Editor") { editorFocusRequest += 1 }
                .keyboardShortcut(.return, modifiers: .command)
            Divider()
            Button("Toggle Pin") {
                if let id = store.selection { store.togglePin(id) }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Previous Note") { store.selectNext(offset: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Next Note") { store.selectNext(offset: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            Divider()
            Button("Delete Note") {
                if let id = store.selection { store.delete(id) }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .textFormatting) {
            Button("Bold") { post(.rayNoteBold) }
                .keyboardShortcut("b", modifiers: .command)
            Button("Italic") { post(.rayNoteItalic) }
                .keyboardShortcut("i", modifiers: .command)
            Button("Underline") { post(.rayNoteUnderline) }
                .keyboardShortcut("u", modifiers: .command)
            Divider()
            Button("Larger") { post(.rayNoteLarger) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller") { post(.rayNoteSmaller) }
                .keyboardShortcut("-", modifiers: .command)
        }
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
