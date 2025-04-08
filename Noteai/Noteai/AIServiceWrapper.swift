import Foundation
import SwiftUI

/// A wrapper class for AIService that can be used as an environment object
class AIServiceWrapper: ObservableObject {
    /// The AI service
    @Published var service: AIService
    
    /// Initialize with a service
    init(service: AIService) {
        self.service = service
    }
}
