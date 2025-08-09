import SwiftUI

// Data structures
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
    let createdDate: Date
    
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return nonEmptyLines.first?.trimmingCharacters(in: .whitespaces) ?? "Empty note"
    }
}

// Apple Notes-style editor with properly positioned clickable checkboxes
struct SimpleInteractiveEditor: View {
    @Binding var content: String
    let onContentChange: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $content)
                .padding()
                .font(.body)
                .onChange(of: content) { _ in
                    onContentChange()
                }
            
            VStack(alignment: .leading, spacing: 0) {
                let lines = content.components(separatedBy: .newlines)
                
                ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                    HStack(alignment: .top, spacing: 0) {
                        if line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
                            let isCompleted = line.hasPrefix("☑ ")
                            
                            Button(action: {
                                toggleCheckboxAt(lineIndex: lineIndex)
                            }) {
                                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isCompleted ? .green : .secondary)
                                    .font(.body)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 17, height: 17)
                            .padding(.top, 1)
                        } else {
                            Color.clear
                                .frame(width: 17, height: 17)
                        }
                        
                        Spacer()
                    }
                    .frame(height: calculateLineHeight())
                }
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            .allowsHitTesting(true)
        }
    }
    
    private func calculateLineHeight() -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return font.pointSize * 1.2
    }
    
    private func toggleCheckboxAt(lineIndex: Int) {
        var lines = content.components(separatedBy: .newlines)
        guard lineIndex < lines.count else { return }
        
        let line = lines[lineIndex]
        if line.hasPrefix("☐ ") {
            lines[lineIndex] = "☑ " + String(line.dropFirst(2))
        } else if line.hasPrefix("☑ ") {
            lines[lineIndex] = "☐ " + String(line.dropFirst(2))
        }
        
        content = lines.joined(separator: "\n")
        onContentChange()
    }
}

// Task Overview View
struct TaskOverview: View {
    let tasks: [TaskItem]
    let onToggle: (Int) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if tasks.isEmpty {
                    Text("No tasks found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(tasks) { task in
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

struct ContentView: View {
    @State private var selectedSection = "Today's Notes"
    @State private var noteContent = "Start typing your note here..."
    @State private var previousContent = ""
    @State private var allNotes: [Note] = []
    @State private var currentNoteId: UUID? = nil
    @State private var selectedNoteIndex: Int? = nil
    @State private var showingDeleteAlert = false
    @State private var activeMode: FormattingMode = .none
    
    enum FormattingMode {
        case none
        case bullet
        case task
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .bullet: return "• Bullet"
            case .task: return "☐ Task"
            }
        }
        
        var prefix: String {
            switch self {
            case .none: return ""
            case .bullet: return "• "
            case .task: return "☐ "
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Navigation Panel
            VStack(alignment: .leading, spacing: 0) {
                Text("Notes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 4) {
                    NavigationButton(title: "Today's Notes", isSelected: selectedSection == "Today's Notes") {
                        selectedSection = "Today's Notes"
                        selectedNoteIndex = nil
                    }
                    
                    NavigationButton(title: "Tasks", isSelected: selectedSection == "Tasks") {
                        selectedSection = "Tasks"
                        selectedNoteIndex = nil
                    }
                    
                    NavigationButton(title: "All Notes", isSelected: selectedSection == "All Notes") {
                        selectedSection = "All Notes"
                        selectedNoteIndex = nil
                    }
                }
                .padding(.horizontal)
                
                if selectedSection == "All Notes" || selectedSection == "Today's Notes" {
                    Divider()
                        .padding(.top, 8)
                    
                    Text(selectedSection == "Today's Notes" ? "Today" : "Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            let notesToShow = selectedSection == "Today's Notes" ? getTodaysNotes() : allNotes
                            
                            if notesToShow.isEmpty {
                                Text(selectedSection == "Today's Notes" ? "No notes created today" : "No notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(Array(notesToShow.enumerated()), id: \.element.id) { index, note in
                                    Button(action: {
                                        if let actualIndex = allNotes.firstIndex(where: { $0.id == note.id }) {
                                            selectedNoteIndex = actualIndex
                                            loadNote(at: actualIndex)
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(isNoteSelected(note) ? .white : .primary)
                                                .lineLimit(1)
                                            
                                            HStack {
                                                Text(note.preview)
                                                    .font(.caption2)
                                                    .foregroundColor(isNoteSelected(note) ? .white : .secondary)
                                                    .lineLimit(2)
                                                
                                                if selectedSection == "Today's Notes" {
                                                    Spacer()
                                                    Text(formatTime(note.createdDate))
                                                        .font(.caption2)
                                                        .foregroundColor(isNoteSelected(note) ? .white : .secondary)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(isNoteSelected(note) ? Color.accentColor : Color.clear)
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // Right Editor Panel
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selectedSection)
                        .font(.title2)
                        .fontWeight(.medium)
                    Spacer()
                    if selectedSection != "Tasks" {
                        Button("New Note") {
                            createNewNote()
                        }
                    }
                }
                .padding()
                
                Divider()
                
                if selectedSection == "Tasks" {
                    TaskOverview(tasks: getAllTasks(), onToggle: toggleTaskByIndex)
                } else if selectedSection == "Today's Notes" && getTodaysNotes().isEmpty {
                    VStack {
                        Spacer()
                        Text("No notes created today")
                            .foregroundColor(.secondary)
                        Text("Click 'New Note' to create your first note of the day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 12) {
                        Button(activeMode == .bullet ? "• Bullet ✓" : "• Bullet") {
                            activeMode = activeMode == .bullet ? .none : .bullet
                            if activeMode == .bullet { addBulletPoint() }
                        }
                        .foregroundColor(activeMode == .bullet ? .blue : .primary)
                        
                        Button(activeMode == .task ? "☐ Task ✓" : "☐ Task") {
                            activeMode = activeMode == .task ? .none : .task
                            if activeMode == .task { addTaskCheckbox() }
                        }
                        .foregroundColor(activeMode == .task ? .blue : .primary)
                        
                        if activeMode != .none {
                            Text("Mode: \(activeMode.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedNoteIndex != nil {
                            Button("🗑 Delete") {
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.05))
                    
                    Divider()
                    
                    SimpleInteractiveEditor(
                        content: $noteContent,
                        onContentChange: saveCurrentNote
                    )
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadNotesFromFile()
            if allNotes.isEmpty {
                createNewNote()
            } else {
                loadNote(at: 0)
            }
            previousContent = noteContent
        }
        .onChange(of: noteContent) { newValue in
            handleAutoFormatting(oldValue: previousContent, newValue: newValue)
            saveCurrentNote()
            previousContent = newValue
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Note"),
                message: Text("Are you sure you want to delete this note? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteCurrentNote()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Formatting helpers
    func addBulletPoint() {
        noteContent += noteContent.isEmpty ? "• " : "\n• "
    }
    func addTaskCheckbox() {
        noteContent += noteContent.isEmpty ? "☐ " : "\n☐ "
    }
    
    func handleAutoFormatting(oldValue: String, newValue: String) {
        guard activeMode != .none else { return }
        
        let oldLines = oldValue.components(separatedBy: .newlines)
        let newLines = newValue.components(separatedBy: .newlines)
        
        if newLines.count > oldLines.count {
            let lastLine = newLines.last ?? ""
            
            if lastLine.isEmpty {
                DispatchQueue.main.async {
                    self.noteContent = newValue + activeMode.prefix
                }
            } else if !lastLine.hasPrefix(activeMode.prefix) {
                var lines = newLines
                lines[lines.count - 1] = activeMode.prefix + lastLine
                DispatchQueue.main.async {
                    self.noteContent = lines.joined(separator: "\n")
                }
            }
        }
        
        // Exit sticky mode if user presses Enter twice
        if newValue.hasSuffix("\n\n") {
            activeMode = .none
        }
    }
    
    // Notes handling
    func createNewNote() {
        let newNote = Note(title: "New Note", content: "", createdDate: Date())
        allNotes.append(newNote)
        selectedNoteIndex = allNotes.count - 1
        noteContent = ""
        saveNotesToFile()
    }
    
    func loadNote(at index: Int) {
        guard index < allNotes.count else { return }
        selectedNoteIndex = index
        noteContent = allNotes[index].content
    }
    
    func saveCurrentNote() {
        guard let index = selectedNoteIndex, index < allNotes.count else { return }
        let lines = noteContent.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? "New Note"
        let title = firstLine.isEmpty ? "New Note" : String(firstLine.prefix(50))
        allNotes[index].title = title
        allNotes[index].content = noteContent
        saveNotesToFile()
    }
    
    // File I/O
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("NotesData.json")
    }
    
    func loadNotesFromFile() {
        do {
            let data = try Data(contentsOf: fileURL)
            allNotes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            allNotes = []
        }
    }
    func saveNotesToFile() {
        do {
            let data = try JSONEncoder().encode(allNotes)
            try data.write(to: fileURL)
        } catch { }
    }
    
    // Task handling
    func getAllTasks() -> [TaskItem] {
        var allTasks: [TaskItem] = []
        var taskId = 0
        for note in allNotes {
            let lines = note.content.components(separatedBy: .newlines)
            for (lineIndex, line) in lines.enumerated() {
                if line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
                    let isCompleted = line.hasPrefix("☑ ")
                    let taskText = String(line.dropFirst(2))
                    allTasks.append(TaskItem(id: taskId, text: taskText, isCompleted: isCompleted, lineIndex: lineIndex, noteId: note.id))
                    taskId += 1
                }
            }
        }
        return allTasks
    }
    func toggleTaskByIndex(_ taskId: Int) {
        let tasks = getAllTasks()
        guard taskId < tasks.count else { return }
        let task = tasks[taskId]
        for (noteIndex, note) in allNotes.enumerated() {
            if note.id == task.noteId {
                var lines = note.content.components(separatedBy: .newlines)
                if task.lineIndex < lines.count {
                    if lines[task.lineIndex].hasPrefix("☐ ") {
                        lines[task.lineIndex] = "☑ " + String(lines[task.lineIndex].dropFirst(2))
                    } else if lines[task.lineIndex].hasPrefix("☑ ") {
                        lines[task.lineIndex] = "☐ " + String(lines[task.lineIndex].dropFirst(2))
                    }
                    allNotes[noteIndex].content = lines.joined(separator: "\n")
                    if selectedNoteIndex == noteIndex {
                        noteContent = allNotes[noteIndex].content
                    }
                    saveNotesToFile()
                }
            }
        }
    }
    
    
    // Misc
    func deleteCurrentNote() {
        guard let index = selectedNoteIndex, index < allNotes.count else { return }
        allNotes.remove(at: index)
        saveNotesToFile()
        if allNotes.isEmpty {
            createNewNote()
        } else {
            loadNote(at: max(0, index - 1))
        }
    }
    func getTodaysNotes() -> [Note] {
        let calendar = Calendar.current
        return allNotes.filter { calendar.isDate($0.createdDate, inSameDayAs: Date()) }
    }
    func isNoteSelected(_ note: Note) -> Bool {
        guard let selectedIndex = selectedNoteIndex else { return false }
        return selectedIndex < allNotes.count && allNotes[selectedIndex].id == note.id
    }
    func formatTime(_ date: Date) -> String {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

