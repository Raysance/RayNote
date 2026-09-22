import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selection: UUID?
    @Published var query = ""

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private let maximumHistoricalBackups = 20

    private var backupDirectory: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    private var latestBackupURL: URL {
        backupDirectory.appendingPathComponent("latest.json")
    }

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
        let candidates = [fileURL, latestBackupURL] + historicalBackupURLs()
        var recoveredData: Data?
        var loadedData: Data?

        for candidate in candidates {
            guard let data = try? Data(contentsOf: candidate),
                  let decoded = try? JSONDecoder().decode([Note].self, from: data) else { continue }
            notes = decoded
            loadedData = data
            recoveredData = candidate == fileURL ? nil : data
            break
        }

        if notes.isEmpty && candidates.allSatisfy({ !FileManager.default.fileExists(atPath: $0.path) }) {
            notes = [
                Note(
                    title: "Welcome to RayNote",
                    body: "A fast place for thoughts\n\nRayNote is designed around the keyboard.\n\n⌘ N  New note\n⌘ F  Search notes\n⌘ B  Bold\n⌘ I  Italic\n⌘ U  Underline\n⌘ +/−  Text size\n\nYour notes stay on this Mac."
                )
            ]
        }

        if let loadedData {
            try? FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
            try? loadedData.write(to: latestBackupURL, options: .atomic)
            if let recoveredData {
                try? recoveredData.write(to: fileURL, options: .atomic)
            }
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
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let newData = try encoder.encode(notes)

            if let previousData = try? Data(contentsOf: fileURL),
               previousData != newData,
               (try? JSONDecoder().decode([Note].self, from: previousData)) != nil {
                let timestamp = Int(Date().timeIntervalSince1970 * 1_000)
                let snapshotURL = backupDirectory.appendingPathComponent(
                    "notes-\(timestamp)-\(UUID().uuidString.prefix(8)).json"
                )
                try previousData.write(to: snapshotURL, options: .atomic)
            }

            try newData.write(to: fileURL, options: .atomic)
            try newData.write(to: latestBackupURL, options: .atomic)
            pruneHistoricalBackups()
        } catch {
            assertionFailure("Could not save notes: \(error)")
        }
    }

    private func historicalBackupURLs() -> [URL] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return files
            .filter { $0.lastPathComponent.hasPrefix("notes-") && $0.pathExtension == "json" }
            .sorted {
                let left = try? $0.resourceValues(forKeys: keys).contentModificationDate
                let right = try? $1.resourceValues(forKeys: keys).contentModificationDate
                return (left ?? .distantPast) > (right ?? .distantPast)
            }
    }

    private func pruneHistoricalBackups() {
        for expiredBackup in historicalBackupURLs().dropFirst(maximumHistoricalBackups) {
            try? FileManager.default.removeItem(at: expiredBackup)
        }
    }
}
