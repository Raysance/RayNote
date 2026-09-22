import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selection: UUID?
    @Published var query = ""

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = support.appendingPathComponent("RayNote", isDirectory: true).appendingPathComponent("notes.json")
        }
        load()
    }

    var filteredNotes: [Note] {
        let sorted = notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(needle) ||
            $0.body.localizedCaseInsensitiveContains(needle)
        }
    }

    var selectedNote: Note? {
        guard let selection else { return nil }
        return notes.first(where: { $0.id == selection })
    }

    @discardableResult
    func createNote() -> UUID {
        let note = Note()
        notes.append(note)
        selection = note.id
        query = ""
        scheduleSave()
        return note.id
    }

    func update(id: UUID, title: String? = nil, body: String? = nil, richTextData: Data? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        if let title { notes[index].title = title }
        if let body { notes[index].body = body }
        if let richTextData { notes[index].richTextData = richTextData }
        notes[index].updatedAt = .now
        scheduleSave()
    }

    func select(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        selection = id
        query = ""
    }

    func togglePin(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
        notes[index].updatedAt = .now
        scheduleSave()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if selection == id { selection = filteredNotes.first?.id }
        scheduleSave()
    }

    func selectNext(offset: Int) {
        let list = filteredNotes
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { $0.id == selection }) ?? (offset > 0 ? -1 : 0)
        let next = min(max(current + offset, 0), list.count - 1)
        selection = list[next].id
    }

    func flush() {
        saveTask?.cancel()
        save()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            notes = [
                Note(
                    title: "Welcome to RayNote",
                    body: "A fast place for thoughts\n\nRayNote is designed around the keyboard.\n\n⌘ N  New note\n⌘ F  Search notes\n⌘ B  Bold\n⌘ I  Italic\n⌘ U  Underline\n⌘ +/−  Text size\n\nYour notes stay on this Mac."
                )
            ]
        }
        selection = notes.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(notes).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save notes: \(error)")
        }
    }
}
