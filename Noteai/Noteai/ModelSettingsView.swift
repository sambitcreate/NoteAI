import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section(header: Text("AI Models")) {
                NavigationLink(destination: ModelSelectionView()) {
                    HStack {
                        Text("Select AI Model")
                        Spacer()
                        Text(selectedModelName())
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Model Settings")) {
                Toggle("Auto-load model on startup", isOn: .constant(true))

                Button {
                    Task {
                        do {
                            if let selectedModelId = modelManager.selectedModelId {
                                try await modelManager.downloadModel(selectedModelId)
                            } else {
                                alertMessage = "No model selected"
                                showingAlert = true
                            }
                        } catch {
                            alertMessage = "Failed to download model: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Text("Download Selected Model")
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                    }
                }
                .disabled(modelManager.selectedModelId == nil)
            }

            Section(header: Text("Storage")) {
                HStack {
                    Text("Storage Location")
                    Spacer()
                    Text("Documents/models")
                        .foregroundColor(.secondary)
                }

                Button {
                    Task {
                        do {
                            try await checkStorageSpace()
                        } catch {
                            alertMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Text("Check Storage Space")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                }

                Button(role: .destructive) {
                    Task {
                        do {
                            if let selectedModelId = modelManager.selectedModelId {
                                try modelManager.deleteModel(selectedModelId)
                                alertMessage = "Model deleted successfully"
                                showingAlert = true
                            } else {
                                alertMessage = "No model selected"
                                showingAlert = true
                            }
                        } catch {
                            alertMessage = "Failed to delete model: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Text("Delete Selected Model")
                        Spacer()
                        Image(systemName: "trash")
                    }
                }
                .disabled(modelManager.selectedModelId == nil)
            }
        }
        .navigationTitle("AI Model Settings")
        .alert("Model Manager", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    /// Get the name of the selected model
    private func selectedModelName() -> String {
        if let selectedModelId = modelManager.selectedModelId,
           let selectedModel = modelManager.models.first(where: { $0.id == selectedModelId }) {
            return selectedModel.name
        }
        return "None"
    }

    /// Check available storage space
    private func checkStorageSpace() async throws {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let values = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                let availableGB = Double(availableCapacity) / 1_000_000_000
                alertMessage = "Available storage: \(String(format: "%.2f", availableGB)) GB"
                showingAlert = true
            }
        } catch {
            throw error
        }
    }
}
