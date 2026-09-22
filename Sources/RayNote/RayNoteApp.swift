import SwiftUI
import AppKit

@main
struct RayNoteApp: App {
    @StateObject private var store = NoteStore()
    @State private var searchFocusRequest = 0
    @State private var editorFocusRequest = 0

    var body: some Scene {
        WindowGroup {
            ContentView(
                store: store,
                searchFocusRequest: searchFocusRequest,
                editorFocusRequest: editorFocusRequest
            )
            .preferredColorScheme(nil)
            .background(WindowAccessor())
            .onDisappear { store.flush() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 780, height: 520)
        .commands {
            AppCommands(
                store: store,
                searchFocusRequest: $searchFocusRequest,
                editorFocusRequest: $editorFocusRequest
            )
        }

        MenuBarExtra("RayNote", systemImage: "note.text") {
            Button("Open RayNote") {
                WindowPolicy.shared.show()
            }
            Button("New Note") {
                store.createNote()
                WindowPolicy.shared.show()
                editorFocusRequest += 1
            }
            Divider()
            Button("Quit RayNote") { NSApp.terminate(nil) }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let sourceWindow = window else { return }
        let window = WindowPolicy.shared.adopt(sourceWindow)
        WindowPolicy.shared.register(window)
        window.title = "RayNote"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)
    }
}

private final class FloatingNotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class WindowPolicy: NSObject {
    static let shared = WindowPolicy()

    private weak var window: NSWindow?
    private var panel: FloatingNotePanel?
    private var shouldStayVisible = true

    override private init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(reapplyWindowPolicy), name: NSWindow.didBecomeKeyNotification, object: nil)
        center.addObserver(self, selector: #selector(reapplyWindowPolicy), name: NSApplication.didBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func adopt(_ sourceWindow: NSWindow) -> NSWindow {
        if let panel {
            return panel
        }
        if let existingPanel = sourceWindow as? FloatingNotePanel {
            panel = existingPanel
            return existingPanel
        }

        let panel = FloatingNotePanel(
            contentRect: sourceWindow.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = sourceWindow.contentView
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.setFrame(sourceWindow.frame, display: false)

        sourceWindow.contentView = nil
        sourceWindow.orderOut(nil)
        sourceWindow.isReleasedWhenClosed = false

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        return panel
    }

    func show() {
        guard let panel else { return }
        shouldStayVisible = true
        apply()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func register(_ window: NSWindow) {
        if self.window !== window {
            if let oldWindow = self.window {
                NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: oldWindow)
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification,
                object: window
            )
            shouldStayVisible = true
        }
        self.window = window
        apply()

        // SwiftUI finishes applying its own scene policy after the hosting view
        // is mounted, so enforce the Space behavior again on the next run loops.
        DispatchQueue.main.async { [weak self] in self?.apply() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.apply() }
    }

    private func apply(bringForward: Bool = false) {
        guard let window else { return }
        let wasVisible = window.isVisible
        window.level = .statusBar
        window.hidesOnDeactivate = false
        if #available(macOS 26.0, *) {
            window.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .ignoresCycle]
        } else {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        }
        if bringForward && shouldStayVisible && (wasVisible || !window.isMiniaturized) {
            window.orderFrontRegardless()
        }
    }

    @objc nonisolated private func reapplyWindowPolicy(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.shouldStayVisible = true
            self?.apply()
        }
    }

    @objc nonisolated private func activeSpaceChanged(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.apply(bringForward: true)
            try? await Task.sleep(for: .milliseconds(250))
            self?.apply(bringForward: true)
        }
    }

    @objc nonisolated private func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.shouldStayVisible = false
        }
    }
}
