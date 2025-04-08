import Foundation
import UIKit
import CoreML

/// GemmaModel is responsible for managing the Gemma 3 1B model
class GemmaModel {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = GemmaModel()
    
    /// The loaded Gemma model
    private var model: MLModel?
    
    /// The tokenizer for Gemma
    private var tokenizer: GemmaTokenizer?
    
    /// Whether the model is currently loaded
    private(set) var isModelLoaded = false
    
    /// Whether the model is currently generating text
    private(set) var isGenerating = false
    
    /// Maximum number of tokens to generate
    private let maxTokens = 512
    
    /// Maximum context length
    private let maxContextLength = 2048
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    // MARK: - Public Methods
    
    /// Load the Gemma model
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        
        do {
            // Check if model exists in documents directory
            let modelURL = try await getModelURL()
            
            // Load the model
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            // Load the model
            model = try MLModel(contentsOf: modelURL, configuration: config)
            
            // Load the tokenizer
            tokenizer = try GemmaTokenizer()
            
            isModelLoaded = true
            print("Gemma model loaded successfully")
        } catch {
            print("Failed to load Gemma model: \(error)")
            throw error
        }
    }
    
    /// Unload the model to free up memory
    func unloadModel() {
        model = nil
        tokenizer = nil
        isModelLoaded = false
    }
    
    /// Generate text using the Gemma model
    func generateText(prompt: String, temperature: Float = 0.7, maxNewTokens: Int = 512) async throws -> String {
        guard isModelLoaded, let model = model, let tokenizer = tokenizer else {
            throw GemmaError.modelNotLoaded
        }
        
        guard !isGenerating else {
            throw GemmaError.alreadyGenerating
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // Format the prompt with the appropriate template
            let formattedPrompt = formatPrompt(prompt)
            
            // Tokenize the prompt
            let inputTokens = try tokenizer.encode(text: formattedPrompt)
            
            // Truncate if needed
            let truncatedTokens = inputTokens.count > maxContextLength 
                ? Array(inputTokens.suffix(maxContextLength)) 
                : inputTokens
            
            // Prepare input for the model
            let inputFeatures = [
                "input_ids": MLMultiArray(truncatedTokens),
                "temperature": MLMultiArray([temperature]),
                "max_tokens": MLMultiArray([Float(maxNewTokens)])
            ]
            
            // Run inference
            let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputFeatures))
            
            // Extract output tokens
            guard let outputTokens = output.featureValue(for: "output_ids")?.multiArrayValue else {
                throw GemmaError.inferenceError
            }
            
            // Decode tokens to text
            let generatedText = try tokenizer.decode(tokens: outputTokens)
            
            return generatedText
        } catch {
            print("Text generation failed: \(error)")
            throw GemmaError.inferenceError
        }
    }
    
    /// Check if the model is downloaded
    func isModelDownloaded() async -> Bool {
        do {
            let modelURL = try await getModelURL()
            return FileManager.default.fileExists(atPath: modelURL.path)
        } catch {
            return false
        }
    }
    
    /// Download the model if needed
    func downloadModelIfNeeded(progressHandler: @escaping (Float) -> Void) async throws {
        // Check if model already exists
        if await isModelDownloaded() {
            return
        }
        
        // Create the models directory if it doesn't exist
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("models")
        
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Download the model
        let modelURL = modelsDirectory.appendingPathComponent("gemma-3-1b-it.mlmodel")
        
        // URL for the model (replace with your actual model URL)
        let downloadURL = URL(string: "https://huggingface.co/google/gemma-3-1b-it/resolve/main/gemma-3-1b-it.mlmodel")!
        
        let (downloadLocation, _) = try await URLSession.shared.download(from: downloadURL, delegate: DownloadDelegate(progressHandler: progressHandler))
        
        // Move the downloaded file to the models directory
        try FileManager.default.moveItem(at: downloadLocation, to: modelURL)
    }
    
    // MARK: - Private Methods
    
    /// Get the URL for the model file
    private func getModelURL() async throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("models")
        let modelURL = modelsDirectory.appendingPathComponent("gemma-3-1b-it.mlmodel")
        
        return modelURL
    }
    
    /// Format the prompt with the appropriate template for Gemma
    private func formatPrompt(_ prompt: String) -> String {
        return """
        <start_of_turn>user
        \(prompt)
        <end_of_turn>
        
        <start_of_turn>model
        """
    }
    
    // MARK: - Helper Classes
    
    /// Download delegate for tracking download progress
    class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        let progressHandler: (Float) -> Void
        
        init(progressHandler: @escaping (Float) -> Void) {
            self.progressHandler = progressHandler
            super.init()
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.progressHandler(progress)
            }
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            // This is handled in the download method
        }
    }
}

// MARK: - Errors

enum GemmaError: Error {
    case modelNotLoaded
    case alreadyGenerating
    case inferenceError
    case tokenizationError
    case downloadError
}

// MARK: - MLMultiArray Extensions

extension MLMultiArray {
    /// Initialize MLMultiArray from an array of integers
    convenience init(_ array: [Int32]) throws {
        let shape = [NSNumber(value: array.count)]
        try self.init(shape: shape, dataType: .int32)
        
        for (index, element) in array.enumerated() {
            self[index] = NSNumber(value: element)
        }
    }
    
    /// Initialize MLMultiArray from an array of floats
    convenience init(_ array: [Float]) throws {
        let shape = [NSNumber(value: array.count)]
        try self.init(shape: shape, dataType: .float32)
        
        for (index, element) in array.enumerated() {
            self[index] = NSNumber(value: element)
        }
    }
}
