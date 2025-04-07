import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID
    var frontText: String
    var backText: String
    var creationDate: Date
    var lastReviewDate: Date?
    var confidenceLevel: Int // 1-5 scale for spaced repetition
    
    // Relationship to Note
    @Relationship(inverse: \Note.flashcards) var relatedNote: Note?

    init(id: UUID = UUID(), 
         frontText: String = "", 
         backText: String = "", 
         creationDate: Date = Date(),
         lastReviewDate: Date? = nil,
         confidenceLevel: Int = 3,
         relatedNote: Note? = nil) {
        self.id = id
        self.frontText = frontText
        self.backText = backText
        self.creationDate = creationDate
        self.lastReviewDate = lastReviewDate
        self.confidenceLevel = confidenceLevel
        self.relatedNote = relatedNote
    }
}
