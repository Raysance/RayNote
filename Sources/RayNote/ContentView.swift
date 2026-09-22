import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: NoteStore
    let searchFocusRequest: Int
    let editorFocusRequest: Int

    @State private var showingNotes = false
    @State private var notePendingDeletion: Note?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            mainContent

            if showingNotes {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { closeNotes() }
                    .onContinuousHover { phase in
                        if case .active = phase { NSCursor.arrow.set() }
                    }

                NotesPanel(
                    store: store,
                    searchFocused: $searchFocused,
                    onSelect: {
                        closeNotes()
                        focusEditor()
                    },
                    onRequestDelete: { notePendingDeletion = $0 }
                )
                .frame(maxWidth: 500, maxHeight: notesPanelHeight)
                .padding(.horizontal, 16)
                .padding(.top, 58)
                .padding(.bottom, 16)
                .onContinuousHover { phase in
                    if case .active = phase { NSCursor.arrow.set() }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
                    )
                )
                .shadow(color: .black.opacity(0.34), radius: 28, y: 16)
            }
        }
        .frame(minWidth: 420, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowBlurView().ignoresSafeArea())
        .onChange(of: searchFocusRequest) { _ in
            withAnimation(.easeOut(duration: 0.14)) { showingNotes = true }
            NSCursor.arrow.set()
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: editorFocusRequest) { _ in focusEditor() }
        .onReceive(NotificationCenter.default.publisher(for: .rayNoteRequestDelete)) { _ in
            notePendingDeletion = store.selectedNote
        }
        .alert("Delete Note?", isPresented: deleteAlertPresented) {
            Button("Cancel", role: .cancel) { notePendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let note = notePendingDeletion { store.delete(note.id) }
                notePendingDeletion = nil
            }
        } message: {
            Text("This will permanently delete “\(notePendingDeletion?.displayTitle ?? "this note")”.")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let note = store.selectedNote {
            VStack(spacing: 0) {
                header(note)
                Divider().opacity(0.45)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Untitled", text: Binding(
                        get: { note.title },
                        set: { store.update(id: note.id, title: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .padding(.top, 20)

                    RichTextEditor(
                        noteID: note.id,
                        initialText: note.body,
                        initialRTF: note.richTextData
                    ) { text, data in
                        store.update(id: note.id, body: text, richTextData: data)
                    }
                    .id(note.id)
                }
                .padding(.horizontal, 26)

                Divider().opacity(0.4)
                Text("\(note.body.count.formatted()) characters")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("A clear space for your next thought").foregroundStyle(.secondary)
                Button("Create Note") { createNote() }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { notePendingDeletion != nil },
            set: { if !$0 { notePendingDeletion = nil } }
        )
    }

    private func header(_ note: Note) -> some View {
        ZStack {
            Text(note.displayTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 150)

            HStack(spacing: 12) {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showingNotes.toggle() }
                    if showingNotes {
                        NSCursor.arrow.set()
                        DispatchQueue.main.async { searchFocused = true }
                    }
                } label: {
                    Image(systemName: showingNotes ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(showingNotes ? Color.accentColor : .secondary)
                .help("Show Notes (⌘F)")

                Button { createNote() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("New Note (⌘N)")
            }
            .padding(.trailing, 15)
        }
        .frame(height: 54)
    }

    private func createNote() {
        closeNotes()
        store.createNote()
        focusEditor()
    }

    private var notesPanelHeight: CGFloat {
        let visibleRows = min(store.filteredNotes.count, 4)
        let pinnedHeader = store.filteredNotes.contains(where: \.isPinned) ? 42 : 0
        return CGFloat(112 + pinnedHeader + max(visibleRows, 1) * 62 + 12)
    }

    private func closeNotes() {
        withAnimation(.easeInOut(duration: 0.16)) {
            showingNotes = false
        }
    }

    private func focusEditor() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .rayNoteFocusEditor, object: nil)
        }
    }
}

private struct WindowBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

private struct NotesPanel: View {
    @ObservedObject var store: NoteStore
    var searchFocused: FocusState<Bool>.Binding
    let onSelect: () -> Void
    let onRequestDelete: (Note) -> Void

    private var pinnedNotes: [Note] { store.filteredNotes.filter(\.isPinned) }
    private var regularNotes: [Note] { store.filteredNotes.filter { !$0.isPinned } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search for notes…", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .focused(searchFocused)
                if !store.query.isEmpty {
                    Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Divider().opacity(0.45)

            if store.filteredNotes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.tertiary)
                    Text("No matching notes").foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if !pinnedNotes.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinnedNotes) { note in noteRow(note) }
                        }

                        notesHeader
                        ForEach(regularNotes) { note in noteRow(note) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).fontWeight(.semibold)
            Spacer()
        }
        .font(.system(size: 13.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .frame(height: 42)
    }

    private var notesHeader: some View {
        HStack {
            Text("Notes").fontWeight(.semibold)
            Spacer()
            Text("\(store.filteredNotes.count)/\(store.notes.count) Notes")
                .foregroundStyle(.secondary)
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .font(.system(size: 13.5))
        .padding(.horizontal, 6)
        .frame(height: 42)
    }

    private func noteRow(_ note: Note) -> some View {
        PanelNoteRow(
            note: note,
            isCurrent: store.selection == note.id,
            onSelect: {
                store.select(note.id)
                onSelect()
            },
            onPin: { store.togglePin(note.id) },
            onDelete: { onRequestDelete(note) }
        )
    }
}

private struct PanelNoteRow: View {
    let note: Note
    let isCurrent: Bool
    let onSelect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(note.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if isCurrent {
                        Circle().fill(.red.opacity(0.85)).frame(width: 6, height: 6)
                        Text("Current")
                    } else {
                        Text("Opened \(note.updatedAt.formatted(.relative(presentation: .named)))")
                    }
                    Text("•")
                    Text("\(note.body.count.formatted()) Characters")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isCurrent || isHovered {
                RowActionButton(
                    systemName: note.isPinned ? "pin.slash" : "pin",
                    action: onPin
                )
                    .help(note.isPinned ? "Unpin" : "Pin")
                RowActionButton(systemName: "trash", action: onDelete)
                    .help("Delete")
            }
        }
        .foregroundStyle(isCurrent || isHovered ? .primary : .secondary)
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(
            isCurrent || isHovered ? Color.primary.opacity(0.10) : .clear,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            if hovering { NSCursor.arrow.set() }
            withAnimation(.easeOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
    }
}

private struct RowActionButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isHovered ? Color.primary.opacity(0.10) : .clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.arrow.set() }
            withAnimation(.easeOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
    }
}
