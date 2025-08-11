import SwiftUI
import AppKit

// STEP 1: Update your existing data structures
struct TaskItem: Identifiable {
    let id: Int
    let text: String
    let isCompleted: Bool
    let lineIndex: Int
    let noteId: UUID
}

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var richTextData: Data? = nil // NEW: Store RTF data
    let createdDate: Date
    var tags: [String] = []
    var isPinned: Bool = false
    var color: String = "default"
    
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return nonEmptyLines.first?.trimmingCharacters(in: .whitespaces) ?? "Empty note"
    }
    
    // NEW: Get attributed string from stored RTF data
    var attributedContent: NSAttributedString {
        guard let richTextData = richTextData,
              let attributed = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else {
            return NSAttributedString(string: content)
        }
        return attributed
    }
    
    // NEW: Save attributed string as RTF data
    mutating func setAttributedContent(_ attributed: NSAttributedString) {
        content = attributed.string
        
        if let rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            richTextData = rtfData
        }
    }
}

struct NoteColor {
    static let colors: [String: Color] = [
        "default": Color.clear,
        "yellow": Color.yellow.opacity(0.3),
        "blue": Color.blue.opacity(0.3),
        "green": Color.green.opacity(0.3),
        "pink": Color.pink.opacity(0.3),
        "purple": Color.purple.opacity(0.3)
    ]
}

// STEP 2: NSTextView wrapped in SwiftUI
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    let onTextChange: (NSAttributedString) -> Void
    let backgroundColor: NSColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: scrollView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.backgroundColor = backgroundColor
        
        // Set initial content
        textView.textStorage?.setAttributedString(attributedText)
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = backgroundColor
        
        // Store reference for toolbar
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Update background color
        textView.backgroundColor = backgroundColor
        nsView.backgroundColor = backgroundColor
        
        // Only update content if it's actually different
        if !textView.textStorage!.isEqual(to: attributedText) {
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            // Restore selection if possible
            if selectedRange.location <= textView.string.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: RichTextEditor
        var textView: NSTextView?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let attributedString = textView.attributedString()
            
            DispatchQueue.main.async {
                self.parent.onTextChange(attributedString)
            }
        }
    }
}

// STEP 3: Rich Text Formatting Toolbar
struct RichTextToolbar: View {
    @StateObject private var toolbarState = ToolbarState()
    
    var body: some View {
        HStack(spacing: 12) {
            // Font Size Controls
            Group {
                Button(action: { toolbarState.increaseFontSize() }) {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase Font Size")
                
                Button(action: { toolbarState.decreaseFontSize() }) {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease Font Size")
                
                Divider()
                    .frame(height: 20)
            }
            
            // Style Controls
            Group {
                Button(action: { toolbarState.toggleBold() }) {
                    Image(systemName: "bold")
                        .foregroundColor(toolbarState.isBold ? .blue : .primary)
                }
                .help("Bold")
                
                Button(action: { toolbarState.toggleItalic() }) {
                    Image(systemName: "italic")
                        .foregroundColor(toolbarState.isItalic ? .blue : .primary)
                }
                .help("Italic")
                
                Button(action: { toolbarState.toggleUnderline() }) {
                    Image(systemName: "underline")
                        .foregroundColor(toolbarState.isUnderlined ? .blue : .primary)
                }
                .help("Underline")
                
                Divider()
                    .frame(height: 20)
            }
            
            // Alignment Controls
            Group {
                Button(action: { toolbarState.setAlignment(.left) }) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(toolbarState.currentAlignment == .left ? .blue : .primary)
                }
                .help("Align Left")
                
                Button(action: { toolbarState.setAlignment(.center) }) {
                    Image(systemName: "text.aligncenter")
                        .foregroundColor(toolbarState.currentAlignment == .center ? .blue : .primary)
                }
                .help("Align Center")
                
                Button(action: { toolbarState.setAlignment(.right) }) {
                    Image(systemName: "text.alignright")
                        .foregroundColor(toolbarState.currentAlignment == .right ? .blue : .primary)
                }
                .help("Align Right")
                
                Divider()
                    .frame(height: 20)
            }
            
            // Special Features
            Group {
                Button(action: { toolbarState.insertBulletPoint() }) {
                    Image(systemName: "list.bullet")
                }
                .help("Bullet Point")
                
                Button(action: { toolbarState.insertTaskCheckbox() }) {
                    Image(systemName: "checkmark.square")
                }
                .help("Task Checkbox")
                
                Button(action: { toolbarState.showColorPanel() }) {
                    Image(systemName: "paintbrush")
                }
                .help("Text Color")
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { _ in
            toolbarState.updateState()
        }
    }
}

// STEP 4: Toolbar State Management
class ToolbarState: ObservableObject {
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderlined = false
    @Published var currentAlignment: NSTextAlignment = .left
    
    private var currentTextView: NSTextView? {
        return NSApp.keyWindow?.firstResponder as? NSTextView
    }
    
    func updateState() {
        guard let textView = currentTextView else { return }
        
        // Update formatting state based on current selection
        if let font = textView.font {
            isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
        }
        
        let range = textView.selectedRange()
        if range.location < textView.textStorage?.length ?? 0 {
            let attributes = textView.textStorage?.attributes(at: range.location, effectiveRange: nil)
            isUnderlined = attributes?[.underlineStyle] != nil
        }
        
        currentAlignment = textView.alignment
    }
    
    func toggleBold() {
        currentTextView?.toggleBold()
        updateState()
    }
    
    func toggleItalic() {
        currentTextView?.toggleItalic()
        updateState()
    }
    
    func toggleUnderline() {
        currentTextView?.toggleUnderline()
        updateState()
    }
    
    func increaseFontSize() {
        currentTextView?.increaseFontSize()
    }
    
    func decreaseFontSize() {
        currentTextView?.decreaseFontSize()
    }
    
    func setAlignment(_ alignment: NSTextAlignment) {
        currentTextView?.setAlignment(alignment)
        currentAlignment = alignment
    }
    
    func insertBulletPoint() {
        currentTextView?.insertText("• ")
    }
    
    func insertTaskCheckbox() {
        currentTextView?.insertText("☐ ")
    }
    
    func showColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(currentTextView)
        colorPanel.setAction(#selector(NSTextView.changeColor(_:)))
        colorPanel.orderFront(nil)
    }
}

// STEP 5: NSTextView Extensions
extension NSTextView {
    func toggleBold() {
        let range = selectedRange()
        let wasEditing = isEditable
        isEditable = true
        
        if range.length == 0 {
            // No selection - toggle typing attributes
            if let font = typingAttributes[.font] as? NSFont {
                let newFont: NSFont
                if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                typingAttributes[.font] = newFont
            }
        } else {
            // Has selection - apply to selected text
            textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                guard let font = value as? NSFont else { return }
                let newFont: NSFont
                if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        isEditable = wasEditing
    }
    
    func toggleItalic() {
        let range = selectedRange()
        let wasEditing = isEditable
        isEditable = true
        
        if range.length == 0 {
            if let font = typingAttributes[.font] as? NSFont {
                let newFont: NSFont
                if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                typingAttributes[.font] = newFont
            }
        } else {
            textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                guard let font = value as? NSFont else { return }
                let newFont: NSFont
                if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        isEditable = wasEditing
    }
    
    func toggleUnderline() {
        let range = selectedRange()
        let wasEditing = isEditable
        isEditable = true
        
        if range.length == 0 {
            if typingAttributes[.underlineStyle] != nil {
                typingAttributes.removeValue(forKey: .underlineStyle)
            } else {
                typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
        } else {
            let hasUnderline = textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil
            
            if hasUnderline {
                textStorage?.removeAttribute(.underlineStyle, range: range)
            } else {
                textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        
        isEditable = wasEditing
    }
    
    func increaseFontSize() {
        adjustFontSize(by: 2)
    }
    
    func decreaseFontSize() {
        adjustFontSize(by: -2)
    }
    
    private func adjustFontSize(by delta: CGFloat) {
        let range = selectedRange()
        let wasEditing = isEditable
        isEditable = true
        
        if range.length == 0 {
            if let font = typingAttributes[.font] as? NSFont {
                let newSize = max(8, min(48, font.pointSize + delta))
                let newFont = NSFont(name: font.fontName, size: newSize) ?? font
                typingAttributes[.font] = newFont
            }
        } else {
            textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                guard let font = value as? NSFont else { return }
                let newSize = max(8, min(48, font.pointSize + delta))
                let newFont = NSFont(name: font.fontName, size: newSize) ?? font
                textStorage?.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        isEditable = wasEditing
    }
    
    func setAlignment(_ alignment: NSTextAlignment) {
        let range = selectedRange()
        let wasEditing = isEditable
        isEditable = true
        
        // Create paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        // Find the paragraph range
        let string = self.string as NSString
        let paragraphRange = string.paragraphRange(for: range)
        
        if range.length == 0 {
            typingAttributes[.paragraphStyle] = paragraphStyle
        } else {
            textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
        }
        
        self.alignment = alignment
        isEditable = wasEditing
    }
}

// STEP 6: Rich Text Note Editor Component
struct RichTextNoteEditor: View {
    @Binding var note: Note
    let onContentChange: () -> Void
    
    private var backgroundColor: NSColor {
        if let color = NoteColor.colors[note.color] {
            return NSColor(color)
        }
        return NSColor.controlBackgroundColor
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Rich Text Toolbar
            RichTextToolbar()
                .background(Color.gray.opacity(0.05))
            
            Divider()
            
            // Rich Text Editor
            RichTextEditor(
                attributedText: Binding(
                    get: { note.attributedContent },
                    set: { newValue in
                        note.setAttributedContent(newValue)
                        onContentChange()
                    }
                ),
                onTextChange: { attributedString in
                    note.setAttributedContent(attributedString)
                    onContentChange()
                },
                backgroundColor: backgroundColor
            )
        }
    }
}

// STEP 7: Tag Input View (keeping your existing functionality)
struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add tag...", text: $newTag, onCommit: {
                    addTag()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    addTag()
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button("×") {
                                removeTag(tag)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// STEP 8: Task Overview (keeping your existing functionality)
struct TaskOverview: View {
    let tasks: [TaskItem]
    let onToggle: (Int) -> Void
    @State private var showCompletedTasks = true
    
    var filteredTasks: [TaskItem] {
        showCompletedTasks ? tasks : tasks.filter { !$0.isCompleted }
    }
    
    var body: some View {
        VStack {
            HStack {
                Toggle("Show Completed", isOn: $showCompletedTasks)
                Spacer()
                Text("\(filteredTasks.count) of \(tasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if filteredTasks.isEmpty {
                        Text(tasks.isEmpty ? "No tasks found" : "No tasks match current filter")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(filteredTasks) { task in
                            HStack {
                                Button(action: {
                                    onToggle(task.id)
                                }) {
                                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                        .foregroundColor(task.isCompleted ? .green : .secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text(task.text)
                                    .strikethrough(task.isCompleted)
                                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.top)
            }
        }
    }
}

// STEP 9: Your existing supporting views
struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void
    let onPin: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                        
                        Text(note.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    Text(note.preview)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(formatTime(note.createdDate))
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        
                        Spacer()
                        
                        if !note.tags.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(note.tags.prefix(2), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(isSelected ? .white : .blue)
                                }
                                if note.tags.count > 2 {
                                    Text("+\(note.tags.count - 2)")
                                        .font(.caption2)
                                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                                }
                            }
                        }
                    }
                }
                
                VStack {
                    Button(action: onPin) {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .foregroundColor(note.isPinned ? .orange : .secondary)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isSelected ? 1 : 0.7)
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        Color.accentColor
                    } else {
                        NoteColor.colors[note.color] ?? Color.clear
                    }
                }
            )
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NavigationButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
