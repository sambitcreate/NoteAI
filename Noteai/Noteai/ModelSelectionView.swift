import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject var modelManager: ModelManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isDownloading = false
    
    var body: some View {
        List {
            Section(header: Text("Available Models")) {
                ForEach(modelManager.models) { model in
                    ModelRow(model: model)
                }
            }
            
            Section(header: Text("Storage")) {
                HStack {
                    Text("Storage Location")
                    Spacer()
                    Text("Documents/models")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    Task {
                        do {
                            try await checkStorageSpace()
                        } catch {
                            alertMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        Text("Check Storage Space")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle("AI Models")
        .alert("Model Manager", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
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

struct ModelRow: View {
    let model: Model
    @EnvironmentObject var modelManager: ModelManager
    @State private var isDownloading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                    
                    Text(model.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if model.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(model.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Size: \(formatBytes(model.size))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if model.isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(Int(model.progress))%")
                            .font(.caption)
                    }
                    
                    ProgressView(value: model.progress, total: 100)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .padding(.top, 4)
            }
            
            HStack {
                if model.isDownloaded {
                    Button(action: {
                        modelManager.selectModel(model.id)
                    }) {
                        Text("Use")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(modelManager.selectedModelId == model.id)
                    
                    Button(action: {
                        Task {
                            do {
                                try modelManager.deleteModel(model.id)
                            } catch {
                                print("Error deleting model: \(error)")
                            }
                        }
                    }) {
                        Text("Delete")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else if model.isDownloading {
                    Button(action: {
                        modelManager.cancelDownload(model.id)
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: {
                        Task {
                            do {
                                try await modelManager.downloadModel(model.id)
                            } catch {
                                print("Error downloading model: \(error)")
                            }
                        }
                    }) {
                        Text("Download")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ModelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ModelSelectionView()
                .environmentObject(ModelManager())
        }
    }
}
