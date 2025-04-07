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
    @State private var showingFlashcards = false // Toggle flashcards view
    @State private var showingQuiz = false // Toggle quiz view

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

                // Other features (Flashcards, Quizzes)
                otherFeaturesSection()

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
                 // Add Flashcard/Quiz buttons
                 Button {
                    showFlashcards()
                 } label: {
                     Label("Flashcards", systemImage: "rectangle.on.rectangle")
                 }
                 .disabled(note.contentForAI.isEmpty)

                 Button {
                    showQuiz()
                 } label: {
                     Label("Quiz", systemImage: "questionmark.circle")
                 }
                 .disabled(note.contentForAI.isEmpty)
            }
         }
         .sheet(isPresented: $showingChat) {
             chatInterface()
                .presentationDetents([.medium, .large]) // Allow resizing
         }
         .sheet(isPresented: $showingFlashcards) {
             FlashcardView(note: note)
                .environmentObject(aiServiceWrapper)
         }
         .sheet(isPresented: $showingQuiz) {
             QuizView(note: note)
                .environmentObject(aiServiceWrapper)
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
            // Add Tagging/Categorization Button
            Button {
                Task { await performCategorize() }
            } label: {
                Label("Suggest Tags", systemImage: "tag")
            }
            .buttonStyle(.bordered)
            .disabled(note.contentForAI.isEmpty)
        }
    }

    // Other Features Section (Flashcards, Quizzes)
    @ViewBuilder
    private func otherFeaturesSection() -> some View {
        Section("Learning Tools") {
            VStack(alignment: .leading) {
                Text("Use AI to create learning materials from this note:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button {
                        showFlashcards()
                    } label: {
                        VStack {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.largeTitle)
                            Text("Flashcards")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(note.contentForAI.isEmpty)

                    Button {
                        showQuiz()
                    } label: {
                        VStack {
                            Image(systemName: "questionmark.circle")
                                .font(.largeTitle)
                            Text("Quiz")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(note.contentForAI.isEmpty)
                }
                .padding(.vertical)
            }
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

    // Navigation functions
    private func showFlashcards() {
        showingFlashcards = true
    }

    private func showQuiz() {
        showingQuiz = true
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

    private func performCategorize() async {
        guard !note.contentForAI.isEmpty else { return }
        do {
            let suggestedTags = try await aiServiceWrapper.service.categorize(text: note.contentForAI)
            // Add new tags to existing tags (avoid duplicates)
            let existingTags = Set(note.tags)
            let newTags = Set(suggestedTags)
            note.tags = Array(existingTags.union(newTags))
            note.lastModifiedDate = Date()
        } catch {
            print("Error categorizing: \(error)")
        }
    }
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
    @MainActor
    func previewContent() -> some View {
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

    return previewContent()
}
