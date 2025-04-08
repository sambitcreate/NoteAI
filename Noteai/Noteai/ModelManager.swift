import Foundation
import Combine
import SwiftUI

class ModelManager: ObservableObject {
    // MARK: - Properties

    enum ModelState {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case error(String)
    }

    enum ModelError: Error {
        case downloadFailed(String)
        case fileSystemError(String)
        case alreadyDownloading
        case modelNotFound
    }

    /// Available models
    @Published var models: [Model] = []

    /// Currently selected model ID
    @Published var selectedModelId: String?

    /// Current state of the model manager
    @Published var modelState: ModelState = .notDownloaded

    /// Download tasks for each model
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]

    /// Progress observers for each model
    private var progressObservers: [String: NSKeyValueObservation] = [:]

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Load models from UserDefaults or use default models
        if let savedModelsData = UserDefaults.standard.data(forKey: "savedModels"),
           let savedModels = try? JSONDecoder().decode([Model].self, from: savedModelsData) {
            self.models = savedModels
        } else {
            self.models = DefaultModels.allModels
        }

        // Check which models are downloaded
        checkDownloadedModels()

        // Load selected model from UserDefaults
        if let selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId") {
            self.selectedModelId = selectedModelId
        }
    }

    // MARK: - Public Methods

    /// Download a specific model
    func downloadModel(_ modelId: String) async throws {
        guard let model = models.first(where: { $0.id == modelId }) else {
            throw ModelError.modelNotFound
        }

        // Check if model already exists
        if isModelDownloaded(modelId) {
            updateModelState(modelId, isDownloaded: true, progress: 100)
            return
        }

        // Check if already downloading
        guard downloadTasks[modelId] == nil else {
            throw ModelError.alreadyDownloading
        }

        // Create models directory if it doesn't exist
        let modelsDirectory = getModelsDirectory()
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Set destination URL
        let destinationURL = modelsDirectory.appendingPathComponent(model.filename)

        // Update model state
        updateModelState(modelId, isDownloading: true, progress: 0)

        // Handle different model types
        switch model.origin {
        case .coreML:
            // For CoreML models like Gemma
            if model.type == ModelType.gemma.rawValue {
                try await downloadCoreMLModel(model, destinationURL: destinationURL)
            } else {
                try await downloadGenericModel(model, destinationURL: destinationURL)
            }
        case .huggingFace:
            // For GGUF models like Qwen
            try await downloadGenericModel(model, destinationURL: destinationURL)
        case .local:
            // Local models don't need downloading
            break
        }
    }

    /// Download a CoreML model (like Gemma) with its vocabulary
    private func downloadCoreMLModel(_ model: Model, destinationURL: URL) async throws {
        // Download the model
        try await downloadGenericModel(model, destinationURL: destinationURL)

        // For Gemma models, also download vocabulary
        if model.type == ModelType.gemma.rawValue {
            // Construct vocabulary URL
            let vocabURL = URL(string: "https://huggingface.co/google/gemma-3-1b-it/resolve/main/tokenizer.json")!
            let vocabDestination = getDocumentsDirectory().appendingPathComponent("gemma_vocab.json")

            // Download vocabulary
            let (tempURL, _) = try await URLSession.shared.download(from: vocabURL)

            // Move vocabulary file to destination
            if FileManager.default.fileExists(atPath: vocabDestination.path) {
                try FileManager.default.removeItem(at: vocabDestination)
            }
            try FileManager.default.moveItem(at: tempURL, to: vocabDestination)
        }
    }

    /// Download a generic model file
    private func downloadGenericModel(_ model: Model, destinationURL: URL) async throws {
        guard let url = URL(string: model.downloadUrl) else {
            throw ModelError.downloadFailed("Invalid download URL")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)

            let downloadTask = session.downloadTask(with: url) { [weak self] tempURL, response, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    // Remove download task and observer
                    self.downloadTasks[model.id] = nil
                    self.progressObservers[model.id]?.invalidate()
                    self.progressObservers[model.id] = nil

                    // Handle errors
                    if let error = error {
                        self.updateModelState(model.id, isDownloading: false, progress: 0)
                        continuation.resume(throwing: ModelError.downloadFailed(error.localizedDescription))
                        return
                    }

                    guard let tempURL = tempURL else {
                        self.updateModelState(model.id, isDownloading: false, progress: 0)
                        continuation.resume(throwing: ModelError.downloadFailed("No file URL"))
                        return
                    }

                    do {
                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }

                        // Move downloaded file to destination
                        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                        // Update model state
                        self.updateModelState(model.id, isDownloaded: true, isDownloading: false, progress: 100)

                        // Save models to UserDefaults
                        self.saveModels()

                        continuation.resume()
                    } catch {
                        self.updateModelState(model.id, isDownloading: false, progress: 0)
                        continuation.resume(throwing: ModelError.fileSystemError(error.localizedDescription))
                    }
                }
            }

            // Observe download progress
            let progressObserver = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    let progressValue = progress.fractionCompleted * 100
                    self.updateModelState(model.id, isDownloading: true, progress: progressValue)
                }
            }

            // Store task and observer
            downloadTasks[model.id] = downloadTask
            progressObservers[model.id] = progressObserver

            // Start download
            downloadTask.resume()
        }
    }

    /// Get the path to a model file
    func getModelPath(_ modelId: String) -> URL? {
        guard let model = models.first(where: { $0.id == modelId }) else {
            return nil
        }

        if model.isLocal, let fullPath = model.fullPath {
            return URL(fileURLWithPath: fullPath)
        }

        return getModelsDirectory().appendingPathComponent(model.filename)
    }

    /// Get the vocabulary path for a model
    func getVocabPath() -> String? {
        let vocabPath = getDocumentsDirectory().appendingPathComponent("gemma_vocab.json").path
        return FileManager.default.fileExists(atPath: vocabPath) ? vocabPath : nil
    }

    /// Cancel a model download
    func cancelDownload(_ modelId: String) {
        guard let downloadTask = downloadTasks[modelId] else {
            return
        }

        // Cancel download task
        downloadTask.cancel()

        // Remove task and observer
        downloadTasks[modelId] = nil
        progressObservers[modelId]?.invalidate()
        progressObservers[modelId] = nil

        // Update model state
        updateModelState(modelId, isDownloading: false, progress: 0)
    }

    /// Delete a downloaded model
    func deleteModel(_ modelId: String) throws {
        guard let model = models.first(where: { $0.id == modelId }) else {
            throw ModelError.modelNotFound
        }

        // Get model file path
        guard let modelPath = getModelPath(modelId) else {
            throw ModelError.modelNotFound
        }

        // Check if file exists
        if FileManager.default.fileExists(atPath: modelPath.path) {
            // Delete file
            try FileManager.default.removeItem(at: modelPath)

            // Update model state
            updateModelState(modelId, isDownloaded: false, progress: 0)

            // If this was the selected model, deselect it
            if selectedModelId == modelId {
                selectedModelId = nil
                UserDefaults.standard.removeObject(forKey: "selectedModelId")
            }

            // Save models to UserDefaults
            saveModels()
        }
    }

    /// Select a model as the active model
    func selectModel(_ modelId: String) {
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "selectedModelId")
    }

    /// Check if a model is currently downloading
    func isDownloading(_ modelId: String) -> Bool {
        if let model = models.first(where: { $0.id == modelId }) {
            return model.isDownloading
        }
        return false
    }

    /// Get the download progress for a model
    func getDownloadProgress(_ modelId: String) -> Double {
        if let model = models.first(where: { $0.id == modelId }) {
            return model.progress
        }
        return 0
    }

    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        guard let model = models.first(where: { $0.id == modelId }),
              let modelPath = getModelPath(modelId) else {
            return false
        }

        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    // MARK: - Private Methods

    /// Check which models are downloaded
    private func checkDownloadedModels() {
        for i in 0..<models.count {
            if let modelPath = getModelPath(models[i].id) {
                models[i].isDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
            } else {
                models[i].isDownloaded = false
            }
        }
    }

    /// Get the models directory
    private func getModelsDirectory() -> URL {
        let documentsDirectory = getDocumentsDirectory()
        return documentsDirectory.appendingPathComponent("models")
    }

    /// Get the documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Update the state of a model
    private func updateModelState(_ modelId: String, isDownloaded: Bool? = nil, isDownloading: Bool? = nil, progress: Double? = nil) {
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            var updatedModel = models[index]

            if let isDownloaded = isDownloaded {
                updatedModel.isDownloaded = isDownloaded
            }

            if let isDownloading = isDownloading {
                updatedModel.isDownloading = isDownloading
            }

            if let progress = progress {
                updatedModel.progress = progress
            }

            models[index] = updatedModel
        }
    }

    /// Save models to UserDefaults
    private func saveModels() {
        if let encodedData = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(encodedData, forKey: "savedModels")
        }
    }
}
