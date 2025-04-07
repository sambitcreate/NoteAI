Okay, let's outline the structure and provide starting code for your Noteai iOS app using SwiftUI and acknowledging the on-device Gemma integration challenge.

**Important Considerations & Challenges:**

1.  **On-Device Gemma Integration:** This is the most complex part.
    *   **Model Availability:** Google provides Gemma models in formats like TensorFlow Lite (`.tflite`). You'll need to obtain the 4B parameter `.tflite` model suitable for mobile inference.
    *   **Inference Engine:** You'll need to use a library like TensorFlow Lite for Swift (or potentially Google's MediaPipe if it supports Gemma tasks easily). This involves:
        *   Adding the library as a dependency (Swift Package Manager).
        *   Bundling the `.tflite` model file with your app.
        *   Writing Swift code to:
            *   Load the model.
            *   Preprocess input data (text tokenization specific to Gemma, image processing, etc.) into the format the model expects (Tensors).
            *   Run inference (this can be computationally intensive, especially for a 4B model on a phone, potentially slow and battery-draining). Run this on a background thread.
            *   Postprocess the model's output tensors back into human-readable text (summaries, answers, categories, etc.).
    *   **Performance:** A 4B parameter model is *large* for on-device mobile use. Inference times might be noticeable, and memory usage could be high. Extensive testing on target devices is crucial. You might need quantization (reducing model precision) to improve performance/size, potentially sacrificing some accuracy.
    *   **Capability Mapping:** You need to map Gemma's capabilities (it's primarily a text generation model) to your features:
        *   **Summarization:** Good fit. Provide text -> Get summary.
        *   **Categorization/Tagging:** Possible. Provide text -> Ask for categories/tags.
        *   **Chat with Content:** Good fit. Provide context (note content) + question -> Get answer.
        *   **Quiz Generation:** Possible. Provide text -> Ask for question/answer pairs.
        *   **Flashcard Generation:** Similar to quiz generation.
        *   **Transcription Analysis:** Gemma doesn't *do* transcription itself (that's Apple's `Speech` framework), but it can process the *resulting text*.
    *   **Abstraction:** We'll create an `AIService` protocol to abstract the AI logic. Initially, we can use a placeholder/mock implementation while the actual Gemma integration is developed.

2.  **Feature Scope:** This app has a *very* broad feature set (multiple input types, summarization, transcription, chat, flashcards, quizzes, organization). Building all of this robustly is a significant undertaking. This code will provide a foundation.

3.  **Dependencies:** You'll need libraries/frameworks for:
    *   TensorFlow Lite (for Gemma)
    *   SwiftUI, SwiftData (Core Apple frameworks)
    *   AVFoundation (for audio recording/playback)
    *   Speech (for transcription)
    *   PhotosUI (for image picking)
    *   PDFKit (for PDF viewing/basic text extraction)
    *   WebKit (potentially for web page rendering/scraping - complex)
    *   LinkPresentation (for URL previews)

4.  **Permissions:** The app will need user permission for Microphone, Speech Recognition, Photo Library access.

**Code Structure Outline:**

*   **NoteaiApp.swift:** App entry point, sets up SwiftData.
*   **Models:** (Using SwiftData)
    *   `Note`: Stores metadata and content for different note types.
    *   `Flashcard`: Stores flashcard data.
*   **Views:**
    *   `ContentView`: Main navigation container (e.g., `NavigationStack` + `List`).
    *   `NoteListView`: Displays the list of notes.
    *   `NoteDetailView`: Displays the content of a single note, provides actions (summarize, chat, etc.).
    *   `CreateNoteView`: Handles the creation of new notes (could be a sheet or separate view).
    *   `AudioRecorderView`: UI for recording audio and showing live transcription.
    *   `ChatView`: Interface for chatting with note content.
    *   `FlashcardView`: Interface for viewing/creating/reviewing flashcards.
    *   `QuizView`: Interface for taking quizzes.
*   **Services:**
    *   `AIService`: Protocol defining AI operations (summarize, chat, etc.).
    *   `GemmaAIService`: Concrete implementation using TensorFlow Lite (Requires significant development).
    *   `MockAIService`: Placeholder implementation for UI development.
    *   `AudioService`: Handles audio recording, playback, and transcription using `AVFoundation` and `Speech`.

**Let's start coding (Foundation):**

**(1) Project Setup:**

*   Create a new Xcode project.
*   Choose the "App" template under the iOS tab.
*   Interface: SwiftUI
*   Life Cycle: SwiftUI App
*   Language: Swift
*   Storage: **SwiftData** (Check the box if available in the template, otherwise, we'll add it manually).
*   Include Tests: Optional.

**(2) Permissions:**

*   Open `Info.plist`.
*   Add the following keys and provide descriptions:
    *   `Privacy - Microphone Usage Description`: "Noteai needs access to your microphone to record audio notes and perform live transcription."
    *   `Privacy - Speech Recognition Usage Description`: "Noteai needs access to speech recognition to transcribe your audio recordings in real-time."
    *   `Privacy - Photo Library Usage Description`: "Noteai needs access to your photo library to allow adding images to your notes."

**(3) SwiftData Model (`Note.swift`):**

```swift
import Foundation
import SwiftData

enum NoteType: String, Codable, CaseIterable {
    case text = "Text"
    case audio = "Audio"
    case image = "Image"
    case pdf = "PDF" // Add others later (web, youtube)
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var creationDate: Date
    var lastModifiedDate: Date
    var title: String // User editable title
    var noteType: NoteType
    var textContent: String? // For text notes, transcriptions, extracted text
    @Attribute(.externalStorage) var audioData: Data? // Store large data externally
    @Attribute(.externalStorage) var imageData: Data? // Store large data externally
    @Attribute(.externalStorage) var pdfData: Data? // Store large data externally
    var originalURL: URL? // For web links, YouTube, potentially source PDFs
    var summary: String?
    var tags: [String] // For organization

    // Relationships (Example - Add if needed later)
    // var flashcards: [Flashcard]? = [] // Requires Flashcard Model

    init(id: UUID = UUID(),
         creationDate: Date = Date(),
         lastModifiedDate: Date = Date(),
         title: String = "New Note",
         noteType: NoteType = .text,
         textContent: String? = nil,
         audioData: Data? = nil,
         imageData: Data? = nil,
         pdfData: Data? = nil,
         originalURL: URL? = nil,
         summary: String? = nil,
         tags: [String] = []) {
        self.id = id
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.title = title
        self.noteType = noteType
        self.textContent = textContent
        self.audioData = audioData
        self.imageData = imageData
        self.pdfData = pdfData
        self.originalURL = originalURL
        self.summary = summary
        self.tags = tags
    }

    // Convenience computed property for display content preview
    var previewContent: String {
        switch noteType {
        case .text:
            return textContent ?? "Empty Text Note"
        case .audio:
            return "Audio Note (\(formattedDuration(from: audioData)))" // Need helper
        case .image:
            return "Image Note"
        case .pdf:
            return "PDF Document: \(originalURL?.lastPathComponent ?? "Unknown")"
        }
    }

    // Placeholder - need helper function
    private func formattedDuration(from data: Data?) -> String {
        // TODO: Implement logic to get duration from audio data if possible, or store duration separately
        return data != nil ? "Audio Data Present" : "No Audio Data"
    }

    // Placeholder for content used by AI
    var contentForAI: String {
        // Combine relevant text data based on type
        // For audio, use transcription (textContent)
        // For PDF, need text extraction logic
        // For Image, potentially use Vision framework for text recognition first
        return textContent ?? ""
    }
}

// Example Flashcard Model (Add later if implementing)
/*
 @Model
 final class Flashcard {
     var id: UUID
     var frontText: String
     var backText: String
     var creationDate: Date
     var relatedNote: Note? // Link back to the note

     init(id: UUID = UUID(), frontText: String = "", backText: String = "", creationDate: Date = Date(), relatedNote: Note? = nil) {
         self.id = id
         self.frontText = frontText
         self.backText = backText
         self.creationDate = creationDate
         self.relatedNote = relatedNote
     }
 }
 */

```

**(4) AI Service Abstraction (`AIService.swift`):**

```swift
import Foundation

// Protocol defining the AI capabilities needed
protocol AIService {
    func summarize(text: String) async throws -> String
    func generateQuiz(text: String, count: Int) async throws -> [(question: String, answer: String)] // Simplified quiz
    func chat(context: String, query: String) async throws -> String
    func categorize(text: String) async throws -> [String] // Suggest tags/categories

    // Add other AI functions as needed (e.g., generate flashcards)
}

// Mock implementation for UI development and testing
class MockAIService: AIService {
    func summarize(text: String) async throws -> String {
        print("🤖 MockAIService: Summarizing text (\(text.count) chars)...")
        try await Task.sleep(nanoseconds: 1_500_000_000) // Simulate network/processing delay
        if text.isEmpty { return "Cannot summarize empty text." }
        let summaryPrefix = "This is a mock summary of the provided content. Key points might include: "
        let length = min(text.count, 100)
        let snippet = String(text.prefix(length)).replacingOccurrences(of: "\n", with: " ")
        return summaryPrefix + snippet + "..."
    }

    func generateQuiz(text: String, count: Int) async throws -> [(question: String, answer: String)] {
        print("🤖 MockAIService: Generating \(count) quiz questions...")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        if text.isEmpty { return [] }
        var questions: [(String, String)] = []
        for i in 1...count {
            questions.append(("\(i). What is mock question \(i)?", "Mock Answer \(i)"))
        }
        return questions
    }

    func chat(context: String, query: String) async throws -> String {
        print("🤖 MockAIService: Chatting with context (\(context.count) chars) about query: \(query)...")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        if query.lowercased().contains("hello") {
            return "Mock response: Hello there! How can I help with this content?"
        }
        return "Mock response: Based on the context, the answer to '\(query)' might be related to mock data."
    }

    func categorize(text: String) async throws -> [String] {
         print("🤖 MockAIService: Categorizing text (\(text.count) chars)...")
         try await Task.sleep(nanoseconds: 800_000_000)
         if text.isEmpty { return ["general"] }
         return ["mock-category", "ai-generated", "example"]
    }
}

// Placeholder for the actual Gemma implementation
class GemmaAIService: AIService {
    // TODO: Implement using TensorFlow Lite Swift library
    // 1. Load the .tflite model
    // 2. Implement pre-processing (tokenization)
    // 3. Implement inference execution (on background thread)
    // 4. Implement post-processing (detokenization)
    // 5. Handle errors and states (loading, processing, ready)

    init() {
        // Initialize TensorFlow Lite interpreter, load model etc.
        print("⚠️ GemmaAIService: Not implemented yet. Using placeholder logic.")
    }

    func summarize(text: String) async throws -> String {
        // TODO: Implement actual Gemma summarization call
        print("⚠️ GemmaAIService: summarize called - returning placeholder.")
        if text.isEmpty { return "Cannot summarize empty text." }
        return "[Gemma Summary Placeholder] for: " + text.prefix(50)
    }

    func generateQuiz(text: String, count: Int) async throws -> [(question: String, answer: String)] {
        // TODO: Implement actual Gemma quiz generation
        print("⚠️ GemmaAIService: generateQuiz called - returning placeholder.")
        return [("Gemma Question Placeholder?", "Gemma Answer Placeholder")]
    }

    func chat(context: String, query: String) async throws -> String {
        // TODO: Implement actual Gemma chat call
        print("⚠️ GemmaAIService: chat called - returning placeholder.")
        return "[Gemma Chat Placeholder] regarding '\(query)'"
    }

    func categorize(text: String) async throws -> [String] {
         // TODO: Implement actual Gemma categorization
         print("⚠️ GemmaAIService: categorize called - returning placeholder.")
         return ["gemma-placeholder-tag"]
    }
}
```

**(5) Main App File (`NoteaiApp.swift`):**

```swift
import SwiftUI
import SwiftData

@main
struct NoteaiApp: App {
    // Initialize the AI Service (Use Mock for now)
    // Switch to GemmaAIService() once implemented
    @StateObject private var aiServiceWrapper = AIServiceWrapper(service: MockAIService())
    // Or for real Gemma: @StateObject private var aiServiceWrapper = AIServiceWrapper(service: GemmaAIService())

    // The SwiftData model container
    var sharedModelContainer: ModelContainer = {
        // Define the schema including all your @Model classes
        let schema = Schema([
            Note.self,
            // Add Flashcard.self here if you implement it
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(aiServiceWrapper) // Provide AI service to the environment
        }
        .modelContainer(sharedModelContainer) // Provide ModelContainer to the environment
    }
}

// Simple wrapper to make AIService usable with @StateObject / @EnvironmentObject
class AIServiceWrapper: ObservableObject {
    @Published var service: AIService
    init(service: AIService) {
        self.service = service
    }
}
```

**(6) Content View (`ContentView.swift`):**

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper
    @State private var showingCreateNoteSheet = false
    @State private var sortOrder = [SortDescriptor(\Note.creationDate, order: .reverse)]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            NoteListView(searchString: searchText, sortOrder: sortOrder)
                .navigationTitle("Noteai")
                .searchable(text: $searchText, prompt: "Search Notes")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Date Created (Newest First)").tag([SortDescriptor(\Note.creationDate, order: .reverse)])
                                Text("Date Created (Oldest First)").tag([SortDescriptor(\Note.creationDate, order: .forward)])
                                Text("Title (A-Z)").tag([SortDescriptor(\Note.title)])
                                Text("Title (Z-A)").tag([SortDescriptor(\Note.title, order: .reverse)])
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingCreateNoteSheet = true
                        } label: {
                            Label("Add Note", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .sheet(isPresented: $showingCreateNoteSheet) {
                    // Present the view to create a new note
                    CreateNoteView()
                    // Pass environment objects if needed, e.g., .environmentObject(aiServiceWrapper)
                }
        }
    }
}

#Preview {
    // Create mock data for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)

    // Add sample notes
    let sampleNotes = [
        Note(title: "Meeting Notes", noteType: .text, textContent: "Discussed project roadmap..."),
        Note(title: "Lecture Recording", noteType: .audio),
        Note(title: "Whiteboard Sketch", noteType: .image)
    ]
    sampleNotes.forEach { container.mainContext.insert($0) }


    return ContentView()
        .modelContainer(container)
        .environmentObject(AIServiceWrapper(service: MockAIService()))

}
```

**(7) Note List View (`NoteListView.swift`):**

```swift
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

// Preview for NoteListView requires the container setup like in ContentView preview
#Preview {
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

```

**(8) Create Note View (Basic Structure) (`CreateNoteView.swift`):**

```swift
import SwiftUI
import PhotosUI // For Image Picker

struct CreateNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper // If needed for immediate processing

    @State private var noteTitle: String = ""
    @State private var noteTextContent: String = ""
    @State private var selectedNoteType: NoteType = .text
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingAudioRecorder = false // State to present audio recorder

    // TODO: Add states for PDF picker, URL input etc.

    var body: some View {
        NavigationView { // Use NavigationView for title/buttons inside sheet
            Form {
                Section("Note Details") {
                    TextField("Title (Optional)", text: $noteTitle)
                    Picker("Note Type", selection: $selectedNoteType) {
                        ForEach(NoteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                // Conditional content based on selected type
                switch selectedNoteType {
                case .text:
                    Section("Content") {
                        TextEditor(text: $noteTextContent)
                            .frame(minHeight: 150)
                    }
                case .image:
                    Section("Image") {
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        }
                        // Use the modern PhotosPicker
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Select Image", systemImage: "photo")
                        }
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task { // Load data asynchronously
                            selectedImageData = try? await newItem?.loadTransferable(type: Data.self)
                        }
                    }
                case .audio:
                    Section("Audio") {
                        Button {
                            // TODO: Request microphone permission before showing
                            showingAudioRecorder = true
                        } label: {
                            Label("Record Audio", systemImage: "waveform")
                        }
                        // TODO: Display recorded audio info if available
                    }
                case .pdf:
                     Section("PDF") {
                         // TODO: Implement PDF selection using .fileImporter
                         Text("PDF selection not implemented yet.")
                     }

                // Add cases for .web, .youtube later
                }

            }
            .navigationTitle("Create New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(!isSavable()) // Disable save if not valid
                }
            }
            .sheet(isPresented: $showingAudioRecorder) {
                // TODO: Present AudioRecorderView here
                Text("Audio Recorder Placeholder")
                // AudioRecorderView(onSave: { audioData, transcript in
                //     self.savedAudioData = audioData
                //     self.noteTextContent = transcript // Store transcript in text content
                //     self.selectedNoteType = .audio // Ensure type is set
                // })
            }
        }
    }

    private func isSavable() -> Bool {
        // Add logic: e.g., require content for the selected type
        switch selectedNoteType {
        case .text: return !noteTextContent.isEmpty
        case .image: return selectedImageData != nil
        case .audio: return false // Requires saved audio data state, update later
        case .pdf: return false // Requires saved pdf data state, update later
        }
    }

    private func saveNote() {
        // Generate default title if empty
        let title = noteTitle.isEmpty ? defaultTitle(for: selectedNoteType) : noteTitle

        // Create the note object
        let newNote = Note(
            title: title,
            noteType: selectedNoteType,
            textContent: noteTextContent, // Will hold text OR transcript
            imageData: selectedImageData,
            pdfData: nil // Add logic later
            // audioData: savedAudioData // Add logic later
        )

        // Insert into SwiftData context
        modelContext.insert(newNote)

        // Optional: Trigger autosave or explicitly save
        // try? modelContext.save()

        print("Note saved: \(newNote.title), Type: \(newNote.noteType)")
    }

    private func defaultTitle(for type: NoteType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())

        switch type {
        case .text: return "Text Note \(dateString)"
        case .audio: return "Audio Note \(dateString)"
        case .image: return "Image Note \(dateString)"
        case .pdf: return "PDF Note \(dateString)"
        }
    }
}

#Preview {
    // Need a ModelContainer and AI Service for the preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)

    return CreateNoteView()
        .modelContainer(container)
        .environmentObject(AIServiceWrapper(service: MockAIService()))
}
```

**(9) Note Detail View (Basic Structure) (`NoteDetailView.swift`):**

```swift
import SwiftUI
import SwiftData
import PDFKit // For PDF View

struct NoteDetailView: View {
    // Use @Bindable to allow editing the note directly from this view
    @Bindable var note: Note
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper
    @Environment(\.modelContext) private var modelContext

    // State for AI operations
    @State private var summaryResult: String?
    @State private var isSummarizing = false
    @State private var chatQuery: String = ""
    @State private var chatResponse: String?
    @State private var isChatting = false
    @State private var showingChat = false // Toggle chat interface

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                // Editable Title
                TextField("Note Title", text: $note.title)
                    .font(.largeTitle)
                    .onChange(of: note.title) { _, _ in note.lastModifiedDate = Date() } // Update modified date

                Text("Created: \(note.creationDate, style: .date) \(note.creationDate, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Display content based on type
                displayNoteContent()

                Divider()

                // AI Features Section
                aiFeaturesSection()

                // Other features (Flashcards, Quizzes - Add Later)
                // otherFeaturesSection()

            }
            .padding()
        }
        .navigationTitle(note.title) // Keep nav title synced (or remove if redundant)
        .navigationBarTitleDisplayMode(.inline)
        // Add toolbar items for editing, deleting etc. if needed
         .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                 Button {
                    showingChat.toggle()
                 } label: {
                     Label("Chat with Note", systemImage: "message.fill")
                 }
                 .disabled(note.contentForAI.isEmpty) // Disable if no text content

                 Spacer()
                 // Add Flashcard/Quiz buttons later
            }
         }
         .sheet(isPresented: $showingChat) {
             chatInterface()
                .presentationDetents([.medium, .large]) // Allow resizing
         }
    }

    // ViewBuilder to dynamically display content
    @ViewBuilder
    private func displayNoteContent() -> some View {
        switch note.noteType {
        case .text:
            TextEditor(text: Binding( // Bind to textContent safely
                get: { note.textContent ?? "" },
                set: { note.textContent = $0; note.lastModifiedDate = Date() }
            ))
            .frame(minHeight: 200)
            .border(Color.gray.opacity(0.2)) // Simple border
        case .audio:
            // TODO: Implement Audio Player View
            VStack(alignment: .leading) {
                 Text("Audio Recording").font(.headline)
                 // Add player controls here (play/pause/scrub)
                 Text("Audio Player UI not implemented.")
                     .foregroundColor(.gray)
                 if let transcript = note.textContent, !transcript.isEmpty {
                     Text("Transcript").font(.headline).padding(.top)
                     Text(transcript)
                 } else {
                      Text("No transcript available.")
                          .foregroundColor(.gray)
                 }
            }
        case .image:
            if let imageData = note.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical)
            } else {
                Text("No Image Data").foregroundColor(.gray)
            }
        case .pdf:
             if let pdfData = note.pdfData {
                 // Use PDFKitRepresentable to show PDF
                 PDFKitRepresentedView(data: pdfData)
                     .frame(height: 400) // Adjust height as needed
             } else {
                  Text("No PDF Data").foregroundColor(.gray)
             }
        }
    }

    // AI Features Section
    @ViewBuilder
    private func aiFeaturesSection() -> some View {
        Section("AI Features") {
            VStack(alignment: .leading) {
                Button {
                    Task { await performSummarize() }
                } label: {
                    Label("Generate Summary", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(isSummarizing || note.contentForAI.isEmpty)

                if isSummarizing {
                    ProgressView().padding(.top, 5)
                } else if let summary = note.summary ?? summaryResult { // Show saved or newly generated
                    Text("Summary:")
                        .font(.headline)
                        .padding(.top)
                    Text(summary)
                        .padding(.bottom)
                        .contextMenu { // Allow copying summary
                             Button {
                                 UIPasteboard.general.string = summary
                             } label: {
                                 Label("Copy Summary", systemImage: "doc.on.doc")
                             }
                         }
                } else if note.contentForAI.isEmpty {
                     Text("No content available to summarize.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            // Add Tagging/Categorization Button if needed
            // Button("Suggest Tags") { Task { await performCategorize() } }
        }
    }

    // Chat Interface (Presented in Sheet)
     @ViewBuilder
     private func chatInterface() -> some View {
         NavigationView { // For title/buttons in sheet
             VStack {
                 ScrollView {
                     VStack(alignment: .leading) {
                         if let response = chatResponse {
                             Text("AI Response:").font(.headline)
                             Text(response)
                                 .padding(.bottom)
                         } else if isChatting {
                              ProgressView("Thinking...")
                         }
                     }
                     .padding()
                 }

                 Spacer() // Push input field to bottom

                 HStack {
                     TextField("Ask about this note...", text: $chatQuery)
                         .textFieldStyle(.roundedBorder)
                         .onSubmit { // Allow sending with Return key
                              Task { await performChat() }
                         }
                     Button {
                         Task { await performChat() }
                     } label: {
                         Image(systemName: "arrow.up.circle.fill")
                             .resizable()
                             .frame(width: 30, height: 30)
                     }
                     .disabled(chatQuery.isEmpty || isChatting)
                 }
                 .padding()
             }
             .navigationTitle("Chat with Note")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                      Button("Done") { showingChat = false }
                 }
             }
         }
     }


    // --- AI Task Functions ---

    private func performSummarize() async {
        guard !note.contentForAI.isEmpty else { return }
        isSummarizing = true
        summaryResult = nil // Clear previous temporary result
        do {
            let generatedSummary = try await aiServiceWrapper.service.summarize(text: note.contentForAI)
            // Save the summary back to the note
            note.summary = generatedSummary
            note.lastModifiedDate = Date()
            // Optional: Explicitly save context if needed
            // try? modelContext.save()
            summaryResult = generatedSummary // Update temporary state too if needed immediately
        } catch {
            print("Error summarizing: \(error)")
            summaryResult = "Error generating summary: \(error.localizedDescription)"
        }
        isSummarizing = false
    }

     private func performChat() async {
         guard !chatQuery.isEmpty, !note.contentForAI.isEmpty else { return }
         isChatting = true
         chatResponse = nil
         let query = chatQuery // Capture current query
         chatQuery = "" // Clear input field immediately
         do {
             let response = try await aiServiceWrapper.service.chat(context: note.contentForAI, query: query)
             chatResponse = response
         } catch {
             print("Error chatting: \(error)")
             chatResponse = "Error getting response: \(error.localizedDescription)"
         }
         isChatting = false
     }

    // Add performCategorize, performGenerateQuiz etc. similarly
}

// --- PDFKit Representable ---
struct PDFKitRepresentedView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous // Or .twoUpContinuous etc.
        pdfView.displaysPageBreaks = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update the view if data changes, if needed
        // uiView.document = PDFDocument(data: data)
    }
}

// --- Preview ---
#Preview {
    // Need a specific note instance for the preview
     let config = ModelConfiguration(isStoredInMemoryOnly: true)
     let container = try! ModelContainer(for: Note.self, configurations: config)

     // Create a sample note to display
     let sampleNote = Note(title: "Sample Text Note", noteType: .text, textContent: "This is the content of the text note.\nIt has multiple lines.\nWe can try summarizing this content.")
     container.mainContext.insert(sampleNote)

     // Wrap in NavigationStack for title display
     return NavigationStack {
        NoteDetailView(note: sampleNote)
     }
        .modelContainer(container)
        .environmentObject(AIServiceWrapper(service: MockAIService()))
}

```

**Next Steps & Further Implementation:**

1.  **Gemma Integration (`GemmaAIService.swift`):** This is the biggest task.
    *   Add the TensorFlow Lite Swift package.
    *   Download a suitable Gemma `.tflite` model (e.g., `gemma-4b-it-gpu-int4.tflite` or similar, check licensing and suitability). Add it to your Xcode project and ensure it's bundled.
    *   Implement the `AIService` protocol methods using the TFLite `Interpreter`. This involves:
        *   **Loading:** `Interpreter(modelPath: ...)`
        *   **Input:** Get input tensor details (`interpreter.inputTensor(at: 0)`), resize if necessary, tokenize your text using a Gemma-compatible tokenizer (you might need to find/port one or use SentencePiece if the model requires it), convert tokens to IDs, and copy data to the input tensor (`interpreter.copy(data, toInputAt: 0)`).
        *   **Inference:** `interpreter.invoke()` (Run this on a background queue!).
        *   **Output:** Get the output tensor (`interpreter.outputTensor(at: 0)`), read the data (usually token IDs), and decode it back into text using the tokenizer.
        *   **Error Handling:** Wrap TFLite calls in `do-catch`.
    *   Instantiate `GemmaAIService` instead of `MockAIService` in `NoteaiApp.swift`.

2.  **Audio Recording/Transcription (`AudioRecorderView.swift`):**
    *   Use `AVAudioEngine` or `AVAudioRecorder` to record audio.
    *   Use `SFSpeechRecognizer` for live transcription. Request `SFSpeechRecognizerAuthorizationStatus` and `AVAudioSession.recordPermission`.
    *   Handle starting/stopping recording, updating the UI with elapsed time and the live transcript.
    *   Save the audio data (`.caf` or `.m4a`) and the final transcript to the `Note` object. You'll need a delegate or callback pattern to pass the data back from the recorder view.

3.  **PDF Handling:**
    *   Use `.fileImporter` modifier in `CreateNoteView` to let the user pick a PDF.
    *   Read the selected file's data using `itemProvider.loadDataRepresentation`.
    *   Store the `Data` in `note.pdfData`.
    *   **Text Extraction (for AI):** Use `PDFDocument(data: pdfData)` and iterate through `page.string` to extract text. Store this in `note.textContent` for summarization/chat. This can be slow for large PDFs; do it in the background.

4.  **Web/YouTube:**
    *   **Web:** Store URL in `note.originalURL`. Use `LinkPresentation` (`LPMetadataProvider`) to get a rich preview. For *summarization*, you'd need to fetch the web page content (HTML) and extract the main text content (difficult, libraries like `ReadabilityKit` might help, or run JS in a hidden `WKWebView`).
    *   **YouTube:** Store URL. Getting transcripts programmatically is hard without dedicated APIs (like YouTube Data API, requires quotas/keys) or potentially fragile web scraping.

5.  **Flashcards/Quizzes:**
    *   Define the `Flashcard` SwiftData `@Model`.
    *   Create views for creating, viewing, and reviewing flashcards (e.g., using `TabView` with `tabViewStyle(.page)`).
    *   Implement AI calls (`generateFlashcards`, `generateQuiz`) in `AIService`.
    *   Add UI in `NoteDetailView` to trigger generation and buttons/navigation links to access the flashcards/quizzes related to that note.
    *   For quizzes, create a view to present questions and check answers.

6.  **UI Polish & UX:**
    *   Add loading indicators for all async operations (AI, file loading).
    *   Handle empty states gracefully (no notes, no summary, no transcript).
    *   Implement proper error handling and display user-friendly error messages.
    *   Refine layout, add icons, ensure accessibility.
    *   Consider iPad layout (`NavigationSplitView`).

This code provides a substantial starting point. Remember that the on-device Gemma integration is technically challenging and requires careful implementation and performance testing. Good luck!