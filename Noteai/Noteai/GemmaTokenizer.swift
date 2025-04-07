import Foundation

final class GemmaTokenizer {
    // MARK: - Properties
    
    private let vocabulary: [String: Int32]
    private let reverseVocabulary: [Int32: String]
    
    // Special tokens
    private let bosToken: Int32 = 1  // Beginning of sequence
    private let eosToken: Int32 = 2  // End of sequence
    private let padToken: Int32 = 0  // Padding
    
    // MARK: - Initialization
    
    init(vocabPath: String) throws {
        // Load vocabulary from JSON file
        let vocabURL = URL(fileURLWithPath: vocabPath)
        let vocabData = try Data(contentsOf: vocabURL)
        let decoder = JSONDecoder()
        self.vocabulary = try decoder.decode([String: Int32].self, from: vocabData)
        
        // Create reverse vocabulary for decoding
        self.reverseVocabulary = Dictionary(uniqueKeysWithValues: vocabulary.map { ($1, $0) })
    }
    
    // Convenience initializer for loading from bundle
    convenience init() throws {
        guard let vocabPath = Bundle.main.path(forResource: "gemma_vocab", ofType: "json") else {
            throw TokenizerError.vocabNotFound
        }
        try self.init(vocabPath: vocabPath)
    }
    
    // MARK: - Methods
    
    func encode(text: String) -> [Int32] {
        // Simple implementation - in practice, you'd need a proper BPE tokenizer
        // This is a placeholder for demonstration
        var tokens: [Int32] = [bosToken]  // Start with BOS token
        
        // Split text into words and convert to tokens
        let words = text.split(separator: " ")
        for word in words {
            if let token = vocabulary[String(word)] {
                tokens.append(token)
            } else {
                // Handle unknown tokens - could use subword tokenization
                for char in word {
                    if let token = vocabulary[String(char)] {
                        tokens.append(token)
                    }
                }
            }
        }
        
        tokens.append(eosToken)  // End with EOS token
        return tokens
    }
    
    func decode(tokens: [Int32]) -> String {
        // Convert tokens back to text
        var result = ""
        
        for token in tokens {
            if token == bosToken || token == eosToken || token == padToken {
                continue  // Skip special tokens
            }
            
            if let word = reverseVocabulary[token] {
                result += word
            }
        }
        
        return result
    }
    
    // MARK: - Error Types
    
    enum TokenizerError: Error {
        case vocabNotFound
        case decodingError
    }
}
