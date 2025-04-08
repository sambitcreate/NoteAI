import Foundation
import Combine

/// QwenAIService implements the AIService protocol using the Qwen 2.5 1.5B model
final class QwenAIService: AIService {
    // MARK: - Properties
    
    private enum QwenError: Error {
        case modelNotLoaded
        case initializationFailed
        case inferenceError(String)
        case timeout
    }
    
    // The Qwen model
    private let qwenModel = QwenModel.shared
    
    // For progress tracking
    @Published var inferenceProgress: Double = 0.0
    
    // For caching
    private var responseCache = [String: String]()
    
    // MARK: - Initialization
    
    init() async throws {
        // Check if model is available
        let isModelAvailable = await qwenModel.isModelDownloaded()
        
        if !isModelAvailable {
            throw QwenError.modelNotLoaded
        }
        
        // Load the model
        try await qwenModel.loadModel()
    }
    
    // MARK: - Private Methods
    
    private func generate(prompt: String, temperature: Float = 0.5, maxTokens: Int = 256) async throws -> String {
        // Check cache first
        if let cachedResponse = responseCache[prompt] {
            return cachedResponse
        }
        
        // Update progress
        updateProgress(0.1)
        
        // Generate text
        let response = try await qwenModel.generateText(
            prompt: prompt,
            temperature: temperature,
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
        qwenModel.unloadModel()
        responseCache.removeAll()
        // Force a garbage collection cycle
        autoreleasepool {}
    }
    
    // MARK: - AIService Protocol Methods
    
    func summarize(text: String) async throws -> String {
        let prompt = """
        Summarize the following text in a concise way:
        
        \(text)
        """
        
        return try await generate(prompt: prompt, temperature: 0.3, maxTokens: 256)
    }
    
    func generateQuiz(text: String, count: Int) async throws -> [(question: String, answer: String)] {
        let prompt = """
        Generate \(count) quiz questions with answers based on the following text:
        
        \(text)
        
        Format each question and answer as "Q: [question]" and "A: [answer]"
        """
        
        let response = try await generate(prompt: prompt, temperature: 0.7, maxTokens: 512)
        return parseQuizResponse(response, count: count)
    }
    
    func chat(context: String, query: String) async throws -> String {
        let prompt = """
        Context:
        \(context)
        
        Question:
        \(query)
        """
        
        return try await generate(prompt: prompt, temperature: 0.7, maxTokens: 512)
    }
    
    func categorize(text: String) async throws -> [String] {
        let prompt = """
        Suggest 3-5 relevant tags or categories for the following text:
        
        \(text)
        
        Return only the tags separated by commas.
        """
        
        let response = try await generate(prompt: prompt, temperature: 0.3, maxTokens: 128)
        return response.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    func generateFlashcards(text: String, count: Int) async throws -> [(front: String, back: String)] {
        let prompt = """
        Create \(count) flashcards based on the following text:
        
        \(text)
        
        Format each flashcard as "Front: [question or concept]" and "Back: [answer or explanation]"
        """
        
        let response = try await generate(prompt: prompt, temperature: 0.7, maxTokens: 512)
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
            print("Qwen inference error: \(error)")
            // Fallback to a simple extractive summary
            return text.split(separator: ".").prefix(3).joined(separator: ". ") + "."
        }
    }
}
