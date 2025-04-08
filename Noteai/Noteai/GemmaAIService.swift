import Foundation
import Combine

final class GemmaAIService: AIService {
    // MARK: - Properties

    private enum GemmaError: Error {
        case modelNotFound
        case initializationFailed
        case inferenceError(String)
        case tokenizationError
        case inputTooLong
        case timeout
    }

    // The Gemma model
    private let gemmaModel = GemmaModel.shared

    // For progress tracking
    @Published var inferenceProgress: Double = 0.0

    // For caching
    private var responseCache = [String: String]()

    // MARK: - Initialization

    init() async throws {
        // Check if model is available
        let isModelAvailable = await gemmaModel.isModelDownloaded()

        if !isModelAvailable {
            throw GemmaError.modelNotFound
        }

        // Load the model
        try await gemmaModel.loadModel()
    }

    // MARK: - Private Methods

    private func generate(prompt: String, maxTokens: Int = 256) async throws -> String {
        // Check cache first
        if let cachedResponse = responseCache[prompt] {
            return cachedResponse
        }

        // Update progress
        updateProgress(0.1)

        // Generate text using GemmaModel
        let response = try await gemmaModel.generateText(
            prompt: prompt,
            temperature: 0.7,
            maxNewTokens: maxTokens
        )

        // Cache the result
        responseCache[prompt] = response

        // Update progress
        updateProgress(1.0)

        return response
    }

    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.inferenceProgress = progress
        }
    }

    // MARK: - Resource Management

    func releaseResources() {
        interpreter = nil
        responseCache.removeAll()
        // Force a garbage collection cycle
        autoreleasepool {}
    }

    // MARK: - AIService Protocol Methods

    func summarize(text: String) async throws -> String {
        let prompt = """
        <start_of_turn>user
        Summarize the following text in a concise way:

        \(text)
        <end_of_turn>

        <start_of_turn>model
        """

        return try await generate(prompt: prompt, maxTokens: 256)
    }

    func generateQuiz(text: String, count: Int) async throws -> [(question: String, answer: String)] {
        let prompt = """
        <start_of_turn>user
        Generate \(count) quiz questions with answers based on the following text:

        \(text)

        Format each question and answer as "Q: [question]" and "A: [answer]"
        <end_of_turn>

        <start_of_turn>model
        """

        let response = try await generate(prompt: prompt, maxTokens: 512)
        return parseQuizResponse(response, count: count)
    }

    func chat(context: String, query: String) async throws -> String {
        let prompt = """
        <start_of_turn>user
        Context:
        \(context)

        Question:
        \(query)
        <end_of_turn>

        <start_of_turn>model
        """

        return try await generate(prompt: prompt, maxTokens: 512)
    }

    func categorize(text: String) async throws -> [String] {
        let prompt = """
        <start_of_turn>user
        Suggest 3-5 relevant tags or categories for the following text:

        \(text)

        Return only the tags separated by commas.
        <end_of_turn>

        <start_of_turn>model
        """

        let response = try await generate(prompt: prompt, maxTokens: 128)
        return response.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func generateFlashcards(text: String, count: Int) async throws -> [(front: String, back: String)] {
        let prompt = """
        <start_of_turn>user
        Create \(count) flashcards based on the following text:

        \(text)

        Format each flashcard as "Front: [question or concept]" and "Back: [answer or explanation]"
        <end_of_turn>

        <start_of_turn>model
        """

        let response = try await generate(prompt: prompt, maxTokens: 512)
        return parseFlashcardResponse(response, count: count)
    }

    // MARK: - Helper Methods

    private func parseQuizResponse(_ response: String, count: Int) -> [(question: String, answer: String)] {
        var result: [(String, String)] = []

        // Simple parsing logic - can be improved
        let lines = response.split(separator: "\n")
        var currentQuestion: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.starts(with: "Q:") {
                currentQuestion = String(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces))
            } else if trimmed.starts(with: "A:"), let question = currentQuestion {
                let answer = String(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces))
                result.append((question, answer))
                currentQuestion = nil
            }
        }

        return result
    }

    private func parseFlashcardResponse(_ response: String, count: Int) -> [(front: String, back: String)] {
        var result: [(String, String)] = []

        // Simple parsing logic - can be improved
        let lines = response.split(separator: "\n")
        var currentFront: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.starts(with: "Front:") {
                currentFront = String(trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces))
            } else if trimmed.starts(with: "Back:"), let front = currentFront {
                let back = String(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
                result.append((front, back))
                currentFront = nil
            }
        }

        return result
    }

    // MARK: - Error Handling with Fallbacks

    func summarizeWithFallback(text: String) async -> String {
        do {
            return try await summarize(text: text)
        } catch {
            print("Gemma inference error: \(error)")
            // Fallback to a simple extractive summary
            return text.split(separator: ".").prefix(3).joined(separator: ". ") + "."
        }
    }
}
