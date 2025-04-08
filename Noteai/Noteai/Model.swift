import Foundation

/// Represents the origin of a model
enum ModelOrigin: String, Codable {
    case huggingFace = "HF"
    case coreML = "COREML"
    case local = "LOCAL"
}

/// Represents an AI model
struct Model: Identifiable, Codable {
    /// Unique identifier for the model
    var id: String
    
    /// Model name
    var name: String
    
    /// Model author
    var author: String
    
    /// Model description
    var description: String
    
    /// Model size in bytes
    var size: Int64
    
    /// Model type (e.g., Gemma, Qwen)
    var type: String
    
    /// URL to download the model
    var downloadUrl: String
    
    /// URL to the model's page on Hugging Face
    var hfUrl: String
    
    /// Filename of the model
    var filename: String
    
    /// Whether the model is downloaded
    var isDownloaded: Bool = false
    
    /// Download progress (0-100)
    var progress: Double = 0
    
    /// Current download speed
    var downloadSpeed: String = ""
    
    /// Origin of the model
    var origin: ModelOrigin
    
    /// Whether the model is currently being downloaded
    var isDownloading: Bool = false
    
    /// Full path to the model file (for local models)
    var fullPath: String?
    
    /// Whether the model is a local model
    var isLocal: Bool = false
    
    /// Model hash for integrity verification
    var hash: String?
    
    /// Default prompt template for the model
    var promptTemplate: String
    
    /// Default stop words for the model
    var stopWords: [String]
    
    /// Default temperature for the model
    var defaultTemperature: Float
    
    /// Default max tokens for the model
    var defaultMaxTokens: Int
}

/// Available model types
enum ModelType: String, CaseIterable {
    case gemma = "Gemma"
    case qwen = "Qwen"
    
    var displayName: String {
        switch self {
        case .gemma:
            return "Gemma"
        case .qwen:
            return "Qwen"
        }
    }
}

/// Default models available in the app
struct DefaultModels {
    static let gemma3_1b = Model(
        id: "google/gemma-3-1b-it",
        name: "Gemma 3 1B Instruct",
        author: "Google",
        description: "Gemma 3 1B is a lightweight model for on-device AI with instruction following capabilities.",
        size: 1_500_000_000,
        type: ModelType.gemma.rawValue,
        downloadUrl: "https://huggingface.co/google/gemma-3-1b-it/resolve/main/gemma-3-1b-it.mlmodel",
        hfUrl: "https://huggingface.co/google/gemma-3-1b-it",
        filename: "gemma-3-1b-it.mlmodel",
        origin: .coreML,
        promptTemplate: """
        <start_of_turn>user
        {prompt}
        <end_of_turn>
        
        <start_of_turn>model
        """,
        stopWords: ["<end_of_turn>"],
        defaultTemperature: 0.7,
        defaultMaxTokens: 512
    )
    
    static let qwen2_5_1_5b = Model(
        id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
        name: "Qwen 2.5 1.5B Instruct",
        author: "Qwen",
        description: "Qwen 2.5 1.5B is a lightweight model with instruction following and multilingual capabilities.",
        size: 1_894_532_128,
        type: ModelType.qwen.rawValue,
        downloadUrl: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf",
        hfUrl: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF",
        filename: "qwen2.5-1.5b-instruct-q8_0.gguf",
        origin: .huggingFace,
        promptTemplate: """
        <|im_start|>user
        {prompt}
        <|im_end|>
        
        <|im_start|>assistant
        """,
        stopWords: ["<|im_end|>"],
        defaultTemperature: 0.5,
        defaultMaxTokens: 512
    )
    
    static let allModels: [Model] = [gemma3_1b, qwen2_5_1_5b]
}
