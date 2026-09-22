import SwiftUI
import AppKit

extension Notification.Name {
    static let rayNoteFocusEditor = Notification.Name("RayNote.focusEditor")
    static let rayNoteBold = Notification.Name("RayNote.bold")
    static let rayNoteItalic = Notification.Name("RayNote.italic")
    static let rayNoteUnderline = Notification.Name("RayNote.underline")
    static let rayNoteLarger = Notification.Name("RayNote.larger")
    static let rayNoteSmaller = Notification.Name("RayNote.smaller")
}

struct RichTextEditor: NSViewRepresentable {
    let noteID: UUID
    let initialText: String
    let initialRTF: Data?
    let onChange: (String, Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 18)
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.typingAttributes = defaultAttributes

        if let initialRTF,
           let attributed = try? NSAttributedString(
               data: initialRTF,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = initialText
            textView.setFont(.systemFont(ofSize: 16), range: NSRange(location: 0, length: textView.string.utf16.count))
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.startObserving()
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    private var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.labelColor]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var onChange: (String, Data) -> Void
        private var observers: [NSObjectProtocol] = []

        init(onChange: @escaping (String, Data) -> Void) { self.onChange = onChange }

        func startObserving() {
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: .rayNoteFocusEditor, object: nil, queue: .main) { [weak self] _ in
                    guard let view = self?.textView else { return }
                    view.window?.makeFirstResponder(view)
                },
                center.addObserver(forName: .rayNoteBold, object: nil, queue: .main) { [weak self] _ in
                    self?.toggleTrait(.boldFontMask)
                },
                center.addObserver(forName: .rayNoteItalic, object: nil, queue: .main) { [weak self] _ in
                    self?.toggleTrait(.italicFontMask)
                },
                center.addObserver(forName: .rayNoteUnderline, object: nil, queue: .main) { [weak self] _ in
                    self?.textView?.underline(nil); self?.commit()
                },
                center.addObserver(forName: .rayNoteLarger, object: nil, queue: .main) { [weak self] _ in
                    self?.changeFontSize(by: 1)
                },
                center.addObserver(forName: .rayNoteSmaller, object: nil, queue: .main) { [weak self] _ in
                    self?.changeFontSize(by: -1)
                }
            ]
        }

        func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }

        func textDidChange(_ notification: Notification) { commit() }

        private func toggleTrait(_ trait: NSFontTraitMask) {
            guard let textView else { return }
            let manager = NSFontManager.shared
            let range = textView.selectedRange()

            if range.length == 0 {
                var attributes = textView.typingAttributes
                let font = (attributes[.font] as? NSFont) ?? .systemFont(ofSize: 16)
                let hasTrait = manager.traits(of: font).contains(trait)
                attributes[.font] = hasTrait
                    ? manager.convert(font, toNotHaveTrait: trait)
                    : manager.convert(font, toHaveTrait: trait)
                textView.typingAttributes = attributes
            } else {
                let firstFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
                let removing = firstFont.map { manager.traits(of: $0).contains(trait) } ?? false
                textView.textStorage?.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let font = (value as? NSFont) ?? .systemFont(ofSize: 16)
                    let converted = removing
                        ? manager.convert(font, toNotHaveTrait: trait)
                        : manager.convert(font, toHaveTrait: trait)
                    textView.textStorage?.addAttribute(.font, value: converted, range: subrange)
                }
                textView.didChangeText()
            }
            commit()
        }

        private func changeFontSize(by delta: CGFloat) {
            guard let textView else { return }
            let range = textView.selectedRange()
            if range.length == 0 {
                var attributes = textView.typingAttributes
                let font = (attributes[.font] as? NSFont) ?? .systemFont(ofSize: 16)
                attributes[.font] = NSFontManager.shared.convert(font, toSize: min(max(font.pointSize + delta, 9), 72))
                textView.typingAttributes = attributes
            } else {
                textView.textStorage?.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let font = (value as? NSFont) ?? .systemFont(ofSize: 16)
                    let size = min(max(font.pointSize + delta, 9), 72)
                    textView.textStorage?.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: size), range: subrange)
                }
                textView.didChangeText()
            }
            commit()
        }

        private func commit() {
            guard let textView, let storage = textView.textStorage else { return }
            let range = NSRange(location: 0, length: storage.length)
            guard let data = try? storage.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else { return }
            onChange(textView.string, data)
        }
    }
}
