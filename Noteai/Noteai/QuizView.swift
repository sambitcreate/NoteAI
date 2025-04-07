import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper

    @Bindable var note: Note
    @State private var quizQuestions: [(question: String, answer: String)] = []
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [String] = []
    @State private var isGenerating = false
    @State private var showingAnswer = false
    @State private var quizCompleted = false
    @State private var questionCount = 5

    var body: some View {
        NavigationStack {
            VStack {
                if quizQuestions.isEmpty {
                    if isGenerating {
                        ProgressView("Generating quiz questions...")
                            .padding()
                    } else {
                        emptyStateView()
                    }
                } else if quizCompleted {
                    quizResultsView()
                } else {
                    quizQuestionView()
                }
            }
            .padding()
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // Empty state view with generation options
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 70))
                .foregroundColor(.gray)

            Text("No Quiz Questions Yet")
                .font(.title2)

            Text("Generate a quiz from this note to test your knowledge.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.vertical)

            Text("How many questions would you like?")
                .font(.headline)

            Picker("Question Count", selection: $questionCount) {
                Text("3 Questions").tag(3)
                Text("5 Questions").tag(5)
                Text("10 Questions").tag(10)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                Task {
                    await generateQuiz()
                }
            } label: {
                Label("Generate Quiz", systemImage: "sparkles")
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

    // Quiz question view
    private func quizQuestionView() -> some View {
        VStack(spacing: 20) {
            // Progress indicator
            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(quizQuestions.count))
                .padding(.horizontal)

            Text("Question \(currentQuestionIndex + 1) of \(quizQuestions.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Question card
            VStack(alignment: .leading, spacing: 20) {
                Text(quizQuestions[currentQuestionIndex].question)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                if showingAnswer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Answer:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(userAnswers[currentQuestionIndex])
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)

                        Text("Correct Answer:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)

                        Text(quizQuestions[currentQuestionIndex].answer)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                    }
                } else {
                    TextField("Type your answer here...", text: $userAnswers[currentQuestionIndex], axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5...)
                        .padding(.vertical)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)

            Spacer()

            // Navigation buttons
            HStack {
                if currentQuestionIndex > 0 {
                    Button {
                        if showingAnswer {
                            showingAnswer = false
                        }
                        currentQuestionIndex -= 1
                        showingAnswer = false
                    } label: {
                        Label("Previous", systemImage: "arrow.left")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20)
                    }
                }

                Spacer()

                if showingAnswer {
                    if currentQuestionIndex < quizQuestions.count - 1 {
                        Button {
                            currentQuestionIndex += 1
                            showingAnswer = false
                        } label: {
                            Label("Next", systemImage: "arrow.right")
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    } else {
                        Button {
                            quizCompleted = true
                        } label: {
                            Label("Finish Quiz", systemImage: "checkmark.circle")
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                } else {
                    Button {
                        showingAnswer = true
                    } label: {
                        Label("Check Answer", systemImage: "checkmark")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .disabled(userAnswers[currentQuestionIndex].isEmpty)
                }
            }
            .padding(.horizontal)
        }
    }

    // Quiz results view
    private func quizResultsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 70))
                .foregroundColor(.green)

            Text("Quiz Completed!")
                .font(.title)

            Text("You've completed the quiz. Review your answers below.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.vertical)

            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<quizQuestions.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Question \(index + 1):")
                                .font(.headline)

                            Text(quizQuestions[index].question)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)

                            Text("Your Answer:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(userAnswers[index])
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)

                            Text("Correct Answer:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(quizQuestions[index].answer)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                }
            }

            Button {
                // Reset the quiz
                quizCompleted = false
                showingAnswer = false
                currentQuestionIndex = 0
                userAnswers = Array(repeating: "", count: quizQuestions.count)
            } label: {
                Label("Restart Quiz", systemImage: "arrow.clockwise")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)

            Button {
                Task {
                    await generateQuiz()
                }
            } label: {
                Label("Generate New Quiz", systemImage: "sparkles")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func generateQuiz() async {
        guard !note.contentForAI.isEmpty else { return }

        isGenerating = true
        quizCompleted = false
        showingAnswer = false
        currentQuestionIndex = 0

        do {
            let generatedQuestions = try await aiServiceWrapper.service.generateQuiz(text: note.contentForAI, count: questionCount)
            quizQuestions = generatedQuestions
            userAnswers = Array(repeating: "", count: quizQuestions.count)
        } catch {
            print("Error generating quiz: \(error)")
        }

        isGenerating = false
    }
}

#Preview {
    // Create mock data for preview
    @MainActor
    func previewContent() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: config)

        // Create a sample note
        let sampleNote = Note(title: "Sample Note", noteType: .text, textContent: "This is sample content for testing quizzes.")
        container.mainContext.insert(sampleNote)

        return QuizView(note: sampleNote)
            .modelContainer(container)
            .environmentObject(AIServiceWrapper(service: MockAIService()))
    }

    return previewContent()
}
