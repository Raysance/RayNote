import Testing
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
}
