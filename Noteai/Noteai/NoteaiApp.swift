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
    @StateObject private var aiServiceWrapper = AIServiceWrapper(service: MockAIService())

    // Flag to track if we've attempted to load Gemma
    @State private var hasAttemptedGemmaLoad = false

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
                .task {
                    if !hasAttemptedGemmaLoad {
                        hasAttemptedGemmaLoad = true
                        await loadGemmaService()
                    }
                }
        }
        .modelContainer(sharedModelContainer) // Provide ModelContainer to the environment
    }

    /// Attempt to load the Gemma service
    private func loadGemmaService() async {
        do {
            // Try to initialize Gemma
            let gemmaService = try await GemmaAIService()
            // Update the service wrapper on the main thread
            await MainActor.run {
                aiServiceWrapper.service = gemmaService
                print("Successfully loaded Gemma AI service")
            }
        } catch {
            print("Failed to initialize Gemma: \(error). Using mock service.")
            // We're already using the mock service as default
        }
    }
}
