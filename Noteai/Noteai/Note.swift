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

    // Relationships
    @Relationship(deleteRule: .cascade) var flashcards: [Flashcard]? = []

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

    // Helper function to get duration from audio data
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
