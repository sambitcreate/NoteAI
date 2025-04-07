import SwiftUI

struct ModelSettingsView: View {
    @StateObject private var modelManager = ModelManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Gemma Model")) {
                VStack(alignment: .leading) {
                    Text("Gemma 3B-4B")
                        .font(.headline)
                    
                    Text("On-device AI model for note processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    modelStateView()
                        .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Model Settings")) {
                Toggle("Use Gemma for AI features", isOn: .constant(true))
                    .disabled(modelManager.modelState != .downloaded)
                
                Button {
                    Task {
                        do {
                            try await modelManager.downloadModelIfNeeded()
                        } catch {
                            alertMessage = "Failed to download model: \(error.localizedDescription)"
                            showingAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Text(downloadButtonText())
                        Spacer()
                        Image(systemName: downloadButtonIcon())
                    }
                }
                .disabled(isDownloadButtonDisabled())
                
                if case .downloading = modelManager.modelState {
                    Button(role: .destructive) {
                        modelManager.cancelDownload()
                    } label: {
                        HStack {
                            Text("Cancel Download")
                            Spacer()
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
            }
            
            Section(header: Text("Storage")) {
                HStack {
                    Text("Model Size")
                    Spacer()
                    Text("~1.5 GB")
                        .foregroundColor(.secondary)
                }
                
                Button(role: .destructive) {
                    // TODO: Implement model deletion
                    alertMessage = "Model deleted successfully"
                    showingAlert = true
                } label: {
                    HStack {
                        Text("Delete Model")
                        Spacer()
                        Image(systemName: "trash")
                    }
                }
                .disabled(modelManager.modelState != .downloaded)
            }
            
            Section(header: Text("Performance")) {
                HStack {
                    Text("Inference Speed")
                    Spacer()
                    Text("Standard")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Memory Usage")
                    Spacer()
                    Text("High")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("AI Model Settings")
        .alert("Model Manager", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    @ViewBuilder
    private func modelStateView() -> some View {
        switch modelManager.modelState {
        case .notDownloaded:
            Text("Not Downloaded")
                .foregroundColor(.red)
                .font(.subheadline)
            
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading...")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .downloaded:
            Text("Downloaded")
                .foregroundColor(.green)
                .font(.subheadline)
            
        case .error(let message):
            VStack(alignment: .leading) {
                Text("Error")
                    .foregroundColor(.red)
                    .font(.subheadline)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func downloadButtonText() -> String {
        switch modelManager.modelState {
        case .notDownloaded:
            return "Download Model"
        case .downloading:
            return "Downloading..."
        case .downloaded:
            return "Re-Download Model"
        case .error:
            return "Retry Download"
        }
    }
    
    private func downloadButtonIcon() -> String {
        switch modelManager.modelState {
        case .notDownloaded:
            return "arrow.down.circle"
        case .downloading:
            return "hourglass"
        case .downloaded:
            return "arrow.down.circle"
        case .error:
            return "arrow.clockwise"
        }
    }
    
    private func isDownloadButtonDisabled() -> Bool {
        if case .downloading = modelManager.modelState {
            return true
        }
        return false
    }
}
