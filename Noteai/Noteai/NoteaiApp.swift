//
//  NoteaiApp.swift
//  Noteai
//
//  Created by Sambit Biswas on 4/7/25.
//

import SwiftUI
import SwiftData

@main
struct NoteaiApp: App {
    // Initialize the AI Service
    @StateObject private var aiServiceWrapper: AIServiceWrapper = {
        do {
            // Try to initialize Gemma
            return AIServiceWrapper(service: try GemmaAIService())
        } catch {
            print("Failed to initialize Gemma: \(error). Falling back to mock.")
            // Fall back to mock service if Gemma initialization fails
            return AIServiceWrapper(service: MockAIService())
        }
    }()

    // The SwiftData model container
    var sharedModelContainer: ModelContainer = {
        // Define the schema including all your @Model classes
        let schema = Schema([
            Note.self,
            Flashcard.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(aiServiceWrapper) // Provide AI service to the environment
        }
        .modelContainer(sharedModelContainer) // Provide ModelContainer to the environment
    }
}
