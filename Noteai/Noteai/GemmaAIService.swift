import Foundation
import TensorFlowLite

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

    private let modelPath: String
    private var interpreter: Interpreter?
    private let tokenizer: GemmaTokenizer

    private let maxInputLength = 2048
    private let maxOutputLength = 512

    // For progress tracking
    @Published var inferenceProgress: Double = 0.0

    // For caching
    private var responseCache = [String: String]()

    // MARK: - Initialization

    init() throws {
        // Use ModelManager to get model paths
        let modelManager = ModelManager()

        // 1. Check if model is downloaded
        guard let modelPath = modelManager.getModelPath() else {
            throw GemmaError.modelNotFound
        }

        self.modelPath = modelPath

        // 2. Initialize tokenizer
        do {
            // Try to use the downloaded vocabulary file
            if let vocabPath = modelManager.getVocabPath() {
                self.tokenizer = try GemmaTokenizer(vocabPath: vocabPath)
            } else {
                // Fall back to the sample vocabulary in the bundle
                guard let bundleVocabPath = Bundle.main.path(forResource: "gemma_vocab_sample", ofType: "json") else {
                    throw GemmaError.tokenizationError
                }
                self.tokenizer = try GemmaTokenizer(vocabPath: bundleVocabPath)
            }
        } catch {
            throw GemmaError.tokenizationError
        }

        // 3. Initialize TensorFlow Lite interpreter
        do {
            self.interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
        } catch {
            throw GemmaError.initializationFailed
        }
    }

    // MARK: - Private Methods

    private func generate(prompt: String, maxTokens: Int = 256) async throws -> String {
        // Check cache first
        if let cachedResponse = responseCache[prompt] {
            return cachedResponse
        }

        // 1. Tokenize input
        guard let inputIds = try? tokenizer.encode(text: prompt) else {
            throw GemmaError.tokenizationError
        }

        // 2. Check if input is too long
        if inputIds.count > maxInputLength {
            throw GemmaError.inputTooLong
        }

        // 3. Prepare input tensor
        let inputTensor = try prepareInputTensor(inputIds: inputIds)

        // 4. Run inference with timeout
        return try await generateWithTimeout(inputTensor: inputTensor, maxTokens: maxTokens)
    }

    private func generateWithTimeout(inputTensor: Data, maxTokens: Int, timeout: TimeInterval = 30) async throws -> String {
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Start generation task
            group.addTask {
                return try await self.runInference(inputTensor: inputTensor, maxTokens: maxTokens)
            }

            // Start timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw GemmaError.timeout
            }

            // Return first completed task result
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func runInference(inputTensor: Data, maxTokens: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Set input tensor
                    try self.interpreter?.copy(inputTensor, toInputAt: 0)

                    // Run inference
                    try self.interpreter?.invoke()

                    // Get output tensor
                    let outputTensor = try self.interpreter?.output(at: 0)
                    let outputIds = self.processOutputTensor(outputTensor)

                    // Decode output
                    let result = self.tokenizer.decode(tokens: outputIds)

                    // Cache the result
                    self.responseCache[String(data: inputTensor, encoding: .utf8) ?? ""] = result

                    // Return result on main thread
                    DispatchQueue.main.async {
                        continuation.resume(returning: result)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: GemmaError.inferenceError(error.localizedDescription))
                    }
                }
            }
        }
    }

    private func prepareInputTensor(inputIds: [Int32]) throws -> Data {
        // Convert input IDs to tensor data
        var inputData = Data(capacity: inputIds.count * MemoryLayout<Int32>.size)
        for id in inputIds {
            var value = id
            inputData.append(Data(bytes: &value, count: MemoryLayout<Int32>.size))
        }
        return inputData
    }

    private func processOutputTensor(_ tensor: Tensor?) -> [Int32] {
        // Process output tensor to get token IDs
        guard let tensor = tensor else { return [] }

        // This is a placeholder implementation
        // The actual implementation depends on the model's output format
        let byteCount = tensor.data.count
        let count = byteCount / MemoryLayout<Int32>.size
        var outputIds = [Int32](repeating: 0, count: count)

        _ = outputIds.withUnsafeMutableBytes { outputBytes in
            tensor.data.copyBytes(to: outputBytes)
        }

        return outputIds
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
