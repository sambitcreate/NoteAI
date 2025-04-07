import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var notes: [Note] // SwiftData query

    init(searchString: String = "", sortOrder: [SortDescriptor<Note>] = [SortDescriptor(\Note.creationDate, order: .reverse)]) {
        // Dynamically filter and sort the notes based on search and sort descriptors
        // Use #Predicate macro for type safety
        let predicate = searchString.isEmpty ? nil : #Predicate<Note> { note in
            note.title.localizedStandardContains(searchString) ||
            (note.textContent != nil && note.textContent!.localizedStandardContains(searchString)) ||
            note.tags.contains { $0.localizedStandardContains(searchString) }
        }

        // Initialize the @Query with dynamic predicate and sort order
        _notes = Query(filter: predicate, sort: sortOrder, animation: .default)
    }

    var body: some View {
        List {
            if notes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes Yet", systemImage: "note.text.badge.plus")
                } description: {
                    Text("Tap the + button to create your first note.")
                }
            } else {
                ForEach(notes) { note in
                    NavigationLink(value: note) { // Use navigationDestination
                        NoteRow(note: note)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
        }
        .navigationDestination(for: Note.self) { note in
             NoteDetailView(note: note)
        }
    }

    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(modelContext.delete)
            // Consider saving explicitly if needed, though autosave often handles it
            // try? modelContext.save()
        }
    }
}

// Row view for the list
struct NoteRow: View {
    @Bindable var note: Note // Use @Bindable for potential future inline edits

    var body: some View {
        HStack {
            Image(systemName: noteTypeIcon(note.noteType))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(note.title).font(.headline)
                Text(note.previewContent)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                Text(note.creationDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // Helper to get an icon based on note type
    private func noteTypeIcon(_ type: NoteType) -> String {
        switch type {
        case .text: return "doc.text.fill"
        case .audio: return "waveform.circle.fill"
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        }
    }
}

// Preview for NoteListView
#Preview {
    @MainActor
    func previewContent() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: config)

        let sampleNotes = [
            Note(title: "Meeting Notes", noteType: .text, textContent: "Discussed project roadmap..."),
            Note(title: "Lecture Recording", noteType: .audio),
            Note(title: "Whiteboard Sketch", noteType: .image)
        ]
        sampleNotes.forEach { container.mainContext.insert($0) }

        // Need NavigationStack for previewing NavigationLink behavior
        return NavigationStack {
            NoteListView()
        }
        .modelContainer(container)
        .environmentObject(AIServiceWrapper(service: MockAIService()))
    }

    return previewContent()
}
