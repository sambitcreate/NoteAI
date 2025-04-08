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

    // Initialize the Model Manager
    @StateObject private var modelManager = ModelManager()

    // Flag to track if we've attempted to load models
    @State private var hasAttemptedModelLoad = false

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
                .environmentObject(modelManager) // Provide model manager to the environment
                .task {
                    if !hasAttemptedModelLoad {
                        hasAttemptedModelLoad = true
                        await loadSelectedModel()
                    }
                }
        }
        .modelContainer(sharedModelContainer) // Provide ModelContainer to the environment
    }

    /// Attempt to load the selected model service
    private func loadSelectedModel() async {
        // Check if a model is selected
        guard let selectedModelId = modelManager.selectedModelId,
              let selectedModel = modelManager.models.first(where: { $0.id == selectedModelId }) else {
            print("No model selected. Using mock service.")
            return
        }

        do {
            // Load the appropriate service based on the model type
            switch selectedModel.type {
            case ModelType.gemma.rawValue:
                // Try to initialize Gemma
                let gemmaService = try await GemmaAIService()
                // Update the service wrapper on the main thread
                await MainActor.run {
                    aiServiceWrapper.service = gemmaService
                    print("Successfully loaded Gemma AI service")
                }

            case ModelType.qwen.rawValue:
                // Try to initialize Qwen
                let qwenService = try await QwenAIService()
                // Update the service wrapper on the main thread
                await MainActor.run {
                    aiServiceWrapper.service = qwenService
                    print("Successfully loaded Qwen AI service")
                }

            default:
                print("Unknown model type: \(selectedModel.type). Using mock service.")
            }
        } catch {
            print("Failed to initialize model service: \(error). Using mock service.")
            // We're already using the mock service as default
        }
    }
}
