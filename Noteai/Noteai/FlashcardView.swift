import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper

    @Bindable var note: Note
    @State private var flashcards: [Flashcard] = []
    @State private var currentIndex = 0
    @State private var isGenerating = false
    @State private var isFlipped = false
    @State private var flashcardCount = 5

    var body: some View {
        NavigationStack {
            VStack {
                if flashcards.isEmpty {
                    if isGenerating {
                        ProgressView("Generating flashcards...")
                            .padding()
                    } else {
                        emptyStateView()
                    }
                } else {
                    flashcardDeckView()
                }
            }
            .padding()
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !flashcards.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive) {
                            // Delete all flashcards
                            deleteAllFlashcards()
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    }
                }
            }
            .onAppear {
                loadFlashcards()
            }
        }
    }

    // Empty state view with generation options
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 70))
                .foregroundColor(.gray)

            Text("No Flashcards Yet")
                .font(.title2)

            Text("Generate flashcards from this note to help you study.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.vertical)

            Text("How many flashcards would you like to generate?")
                .font(.headline)

            Picker("Flashcard Count", selection: $flashcardCount) {
                Text("3 Cards").tag(3)
                Text("5 Cards").tag(5)
                Text("10 Cards").tag(10)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                Task {
                    await generateFlashcards()
                }
            } label: {
                Label("Generate Flashcards", systemImage: "sparkles")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            .disabled(note.contentForAI.isEmpty)
        }
        .padding()
    }

    // Flashcard deck view
    private func flashcardDeckView() -> some View {
        VStack {
            // Card counter
            Text("\(currentIndex + 1) of \(flashcards.count)")
                .font(.caption)
                .padding(.top)

            // Flashcard
            ZStack {
                // Back card (answer)
                flashcardView(isQuestion: false)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : 180),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                    .opacity(isFlipped ? 1 : 0)

                // Front card (question)
                flashcardView(isQuestion: true)
                    .rotation3DEffect(
                        .degrees(isFlipped ? -180 : 0),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                    .opacity(isFlipped ? 0 : 1)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isFlipped.toggle()
                }
            }
            .padding()

            // Navigation controls
            HStack(spacing: 40) {
                Button {
                    withAnimation {
                        previousCard()
                    }
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.gray)
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.5 : 1)

                // Confidence level buttons
                if isFlipped {
                    HStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { level in
                            Button {
                                updateConfidence(level: level)
                                nextCard()
                            } label: {
                                Text("\(level)")
                                    .font(.headline)
                                    .frame(width: 40, height: 40)
                                    .background(confidenceColor(for: level))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isFlipped.toggle()
                        }
                    } label: {
                        Text("Reveal Answer")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }

                Button {
                    withAnimation {
                        nextCard()
                    }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                }
                .disabled(currentIndex == flashcards.count - 1)
                .opacity(currentIndex == flashcards.count - 1 ? 0.5 : 1)
            }
            .padding(.vertical)

            // Generate more button
            Button {
                Task {
                    await generateFlashcards()
                }
            } label: {
                Label("Generate More", systemImage: "plus.circle")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
            }
            .padding(.top)
        }
    }

    // Individual flashcard view
    private func flashcardView(isQuestion: Bool) -> some View {
        let currentFlashcard = flashcards[currentIndex]
        let content = isQuestion ? currentFlashcard.frontText : currentFlashcard.backText

        return VStack {
            Text(isQuestion ? "Question" : "Answer")
                .font(.caption)
                .padding(.top, 8)
                .foregroundColor(.secondary)

            Spacer()

            Text(content)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            if !isQuestion {
                HStack {
                    Text("Confidence:")
                        .font(.caption)

                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= currentFlashcard.confidenceLevel ? confidenceColor(for: currentFlashcard.confidenceLevel) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions

    private func loadFlashcards() {
        if let noteFlashcards = note.flashcards, !noteFlashcards.isEmpty {
            flashcards = noteFlashcards
        }
    }

    private func generateFlashcards() async {
        guard !note.contentForAI.isEmpty else { return }

        isGenerating = true

        do {
            let generatedPairs = try await aiServiceWrapper.service.generateFlashcards(text: note.contentForAI, count: flashcardCount)

            // Create flashcard objects
            for pair in generatedPairs {
                let newFlashcard = Flashcard(
                    frontText: pair.front,
                    backText: pair.back,
                    relatedNote: note
                )
                modelContext.insert(newFlashcard)

                // Add to the note's flashcards collection
                if note.flashcards == nil {
                    note.flashcards = []
                }
                note.flashcards?.append(newFlashcard)
            }

            // Reload flashcards
            loadFlashcards()

        } catch {
            print("Error generating flashcards: \(error)")
        }

        isGenerating = false
    }

    private func nextCard() {
        withAnimation {
            if currentIndex < flashcards.count - 1 {
                isFlipped = false
                currentIndex += 1
            }
        }
    }

    private func previousCard() {
        withAnimation {
            if currentIndex > 0 {
                isFlipped = false
                currentIndex -= 1
            }
        }
    }

    private func updateConfidence(level: Int) {
        if currentIndex < flashcards.count {
            flashcards[currentIndex].confidenceLevel = level
            flashcards[currentIndex].lastReviewDate = Date()
        }
    }

    private func deleteAllFlashcards() {
        // Delete all flashcards from the database
        if let noteFlashcards = note.flashcards {
            for flashcard in noteFlashcards {
                modelContext.delete(flashcard)
            }
        }

        // Clear the note's flashcards collection
        note.flashcards = []

        // Clear the local array
        flashcards = []
    }

    private func confidenceColor(for level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .green
        case 4: return .blue
        case 5: return .purple
        default: return .gray
        }
    }
}

#Preview {
    // Create mock data for preview
    @MainActor
    func previewContent() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: config)

        // Create a sample note
        let sampleNote = Note(title: "Sample Note", noteType: .text, textContent: "This is sample content for testing flashcards.")
        container.mainContext.insert(sampleNote)

        // Create sample flashcards
        let flashcards = [
            Flashcard(frontText: "What is SwiftUI?", backText: "A declarative framework for building user interfaces across Apple platforms.", confidenceLevel: 3, relatedNote: sampleNote),
            Flashcard(frontText: "What is SwiftData?", backText: "Apple's framework for data persistence that works with SwiftUI.", confidenceLevel: 2, relatedNote: sampleNote)
        ]

        flashcards.forEach { container.mainContext.insert($0) }
        sampleNote.flashcards = flashcards

        return FlashcardView(note: sampleNote)
            .modelContainer(container)
            .environmentObject(AIServiceWrapper(service: MockAIService()))
    }

    return previewContent()
}
