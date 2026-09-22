import Testing
import Foundation
@testable import RayNote

struct NoteTests {
    @Test func displayTitleFallsBackToBody() {
        let note = Note(title: "  ", body: "First useful line\nMore")
        #expect(note.displayTitle == "First useful line")
    }

    @Test func previewRemovesCommonMarkdownCharacters() {
        let note = Note(body: "# Hello\n**World**")
        #expect(note.preview == "Hello World")
    }

    @Test @MainActor func recoversFromLatestBackupWhenPrimaryFileIsCorrupt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("notes.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = NoteStore(fileURL: fileURL)
        let createdID = original.createNote()
        original.update(id: createdID, title: "Recover me", body: "Backup content")
        original.flush()

        try Data("not valid json".utf8).write(to: fileURL, options: .atomic)

        let recovered = NoteStore(fileURL: fileURL)
        #expect(recovered.notes.contains { $0.title == "Recover me" && $0.body == "Backup content" })
        #expect((try? JSONDecoder().decode([Note].self, from: Data(contentsOf: fileURL))) != nil)
    }
}
