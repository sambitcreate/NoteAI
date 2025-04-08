import Foundation
import Combine

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
    }

    @Published var modelState: ModelState = .notDownloaded

    private let modelURL = URL(string: "https://storage.googleapis.com/gemma-models-for-ios/gemma-3b-4b-it.tflite")!
    private let vocabURL = URL(string: "https://storage.googleapis.com/gemma-models-for-ios/gemma_vocab.json")!

    private var downloadTask: URLSessionDownloadTask?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        checkIfModelExists()
    }

    // MARK: - Public Methods

    func downloadModelIfNeeded() async throws {
        // Check if model already exists
        if modelExists() {
            DispatchQueue.main.async {
                self.modelState = .downloaded
            }
            return
        }

        // Check if already downloading
        guard downloadTask == nil else {
            throw ModelError.alreadyDownloading
        }

        // Update state to downloading
        DispatchQueue.main.async {
            self.modelState = .downloading(progress: 0.0)
        }

        // Use GemmaModel to download the model
        try await GemmaModel.shared.downloadModelIfNeeded { progress in
            DispatchQueue.main.async {
                self.modelState = .downloading(progress: progress)
            }
        }

        // Download vocabulary
        try await GemmaTokenizer.downloadVocabularyIfNeeded()

        DispatchQueue.main.async {
            self.modelState = .downloaded
        }
    }

    func getModelPath() -> String? {
        guard modelExists() else { return nil }
        return getDocumentsDirectory().appendingPathComponent("models/gemma-3-1b-it.mlmodel").path
    }

    func getVocabPath() -> String? {
        let vocabPath = getDocumentsDirectory().appendingPathComponent("gemma_vocab.json").path
        return FileManager.default.fileExists(atPath: vocabPath) ? vocabPath : nil
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        DispatchQueue.main.async {
            self.modelState = .notDownloaded
        }
    }

    // MARK: - Private Methods

    private func checkIfModelExists() {
        if modelExists() {
            modelState = .downloaded
        } else {
            modelState = .notDownloaded
        }
    }

    private func modelExists() -> Bool {
        let modelPath = getDocumentsDirectory().appendingPathComponent("models/gemma-3-1b-it.mlmodel").path
        return FileManager.default.fileExists(atPath: modelPath)
    }

    private func downloadModel() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)

            downloadTask = session.downloadTask(with: modelURL) { [weak self] tempURL, response, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.modelState = .error(error.localizedDescription)
                    }
                    continuation.resume(throwing: ModelError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let tempURL = tempURL else {
                    DispatchQueue.main.async {
                        self.modelState = .error("Download failed: No file URL")
                    }
                    continuation.resume(throwing: ModelError.downloadFailed("No file URL"))
                    return
                }

                let destinationURL = self.getDocumentsDirectory().appendingPathComponent("gemma-3b-4b-it.tflite")

                do {
                    // Remove any existing file
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    // Move file to documents directory
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    continuation.resume()
                } catch {
                    DispatchQueue.main.async {
                        self.modelState = .error(error.localizedDescription)
                    }
                    continuation.resume(throwing: ModelError.fileSystemError(error.localizedDescription))
                }
            }

            // Track download progress
            let observation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                DispatchQueue.main.async {
                    self?.modelState = .downloading(progress: progress.fractionCompleted)
                }
            }

            if let observation = observation {
                observation.invalidate()
            }

            downloadTask?.resume()
        }
    }

    private func downloadVocabulary() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)

            let task = session.downloadTask(with: vocabURL) { [weak self] tempURL, response, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.modelState = .error(error.localizedDescription)
                    }
                    continuation.resume(throwing: ModelError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let tempURL = tempURL else {
                    DispatchQueue.main.async {
                        self.modelState = .error("Download failed: No file URL")
                    }
                    continuation.resume(throwing: ModelError.downloadFailed("No file URL"))
                    return
                }

                let destinationURL = self.getDocumentsDirectory().appendingPathComponent("gemma_vocab.json")

                do {
                    // Remove any existing file
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    // Move file to documents directory
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    continuation.resume()
                } catch {
                    DispatchQueue.main.async {
                        self.modelState = .error(error.localizedDescription)
                    }
                    continuation.resume(throwing: ModelError.fileSystemError(error.localizedDescription))
                }
            }

            task.resume()
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
