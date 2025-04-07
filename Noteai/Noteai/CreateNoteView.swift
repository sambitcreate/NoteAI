import SwiftUI
import SwiftData
import PhotosUI // For Image Picker
import PDFKit
import UniformTypeIdentifiers // For file importing

struct CreateNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper // If needed for immediate processing

    // Audio service for recording
    @StateObject private var audioService = AudioService()

    @State private var noteTitle: String = ""
    @State private var noteTextContent: String = ""
    @State private var selectedNoteType: NoteType = .text
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingAudioRecorder = false // State to present audio recorder
    @State private var savedAudioData: Data?
    @State private var audioTranscript: String?
    @State private var showingPDFPicker = false
    @State private var selectedPDFData: Data?
    @State private var pdfURL: URL?

    var body: some View {
        NavigationView { // Use NavigationView for title/buttons inside sheet
            Form {
                Section("Note Details") {
                    TextField("Title (Optional)", text: $noteTitle)
                    Picker("Note Type", selection: $selectedNoteType) {
                        ForEach(NoteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                // Conditional content based on selected type
                switch selectedNoteType {
                case .text:
                    Section("Content") {
                        TextEditor(text: $noteTextContent)
                            .frame(minHeight: 150)
                    }
                case .image:
                    Section("Image") {
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        }
                        // Use the modern PhotosPicker
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Select Image", systemImage: "photo")
                        }
                    }
                    .onChange(of: selectedPhotoItem) { oldItem, newItem in
                        Task { // Load data asynchronously
                            selectedImageData = try? await newItem?.loadTransferable(type: Data.self)
                        }
                    }
                case .audio:
                    Section("Audio") {
                        if let audioData = savedAudioData {
                            // Show audio info if available
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text("Audio Recording")
                                        .font(.headline)
                                    if let duration = audioService.getDuration(from: audioData) {
                                        Text("Duration: \(formatDuration(duration))")
                                            .font(.caption)
                                    }
                                }
                                Spacer()
                                Button {
                                    // Play the audio
                                    audioService.playAudio(data: audioData)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                }
                            }

                            if let transcript = audioTranscript, !transcript.isEmpty {
                                Text("Transcript:")
                                    .font(.headline)
                                    .padding(.top)
                                Text(transcript)
                            }

                            Button(role: .destructive) {
                                // Clear the audio
                                savedAudioData = nil
                                audioTranscript = nil
                            } label: {
                                Label("Clear Recording", systemImage: "trash")
                            }
                        } else {
                            Button {
                                // Show audio recorder
                                showingAudioRecorder = true
                            } label: {
                                Label("Record Audio", systemImage: "mic.circle")
                            }
                        }
                    }
                case .pdf:
                     Section("PDF") {
                         if let pdfData = selectedPDFData, let pdfDoc = PDFDocument(data: pdfData) {
                             VStack(alignment: .leading) {
                                 Text("PDF Document")
                                     .font(.headline)
                                 if let pdfURL = pdfURL {
                                     Text(pdfURL.lastPathComponent)
                                         .font(.caption)
                                 }
                                 Text("Pages: \(pdfDoc.pageCount)")
                                     .font(.caption)
                             }

                             Button(role: .destructive) {
                                 // Clear the PDF
                                 selectedPDFData = nil
                                 pdfURL = nil
                             } label: {
                                 Label("Clear PDF", systemImage: "trash")
                             }
                         } else {
                             Button {
                                 showingPDFPicker = true
                             } label: {
                                 Label("Select PDF", systemImage: "doc.fill")
                             }
                         }
                     }
                }

            }
            .navigationTitle("Create New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(!isSavable()) // Disable save if not valid
                }
            }
            .sheet(isPresented: $showingAudioRecorder) {
                AudioRecorderView(audioService: audioService, onSave: { audioData, transcript in
                    self.savedAudioData = audioData
                    self.audioTranscript = transcript
                })
            }
            .fileImporter(
                isPresented: $showingPDFPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile: URL = try result.get().first else { return }

                    // Create a security-scoped bookmark
                    if selectedFile.startAccessingSecurityScopedResource() {
                        defer { selectedFile.stopAccessingSecurityScopedResource() }

                        // Load the PDF data
                        selectedPDFData = try Data(contentsOf: selectedFile)
                        pdfURL = selectedFile

                        // Extract text from PDF for AI processing
                        if let pdfDocument = PDFDocument(data: selectedPDFData!) {
                            var text = ""
                            for i in 0..<pdfDocument.pageCount {
                                if let page = pdfDocument.page(at: i),
                                   let pageText = page.string {
                                    text += pageText + "\n"
                                }
                            }
                            noteTextContent = text
                        }
                    }
                } catch {
                    print("Error selecting PDF: \(error)")
                }
            }
        }
        .onAppear {
            // Set up audio service delegate
            audioService.delegate = self
        }
    }

    private func isSavable() -> Bool {
        // Add logic: e.g., require content for the selected type
        switch selectedNoteType {
        case .text: return !noteTextContent.isEmpty
        case .image: return selectedImageData != nil
        case .audio: return savedAudioData != nil
        case .pdf: return selectedPDFData != nil
        }
    }

    private func saveNote() {
        // Generate default title if empty
        let title = noteTitle.isEmpty ? defaultTitle(for: selectedNoteType) : noteTitle

        // Create the note object
        let newNote = Note(
            title: title,
            noteType: selectedNoteType,
            textContent: selectedNoteType == .text ? noteTextContent : audioTranscript, // Will hold text OR transcript
            audioData: savedAudioData,
            imageData: selectedImageData,
            pdfData: selectedPDFData,
            originalURL: pdfURL
        )

        // Insert into SwiftData context
        modelContext.insert(newNote)

        // Optional: Trigger autosave or explicitly save
        // try? modelContext.save()

        print("Note saved: \(newNote.title), Type: \(newNote.noteType)")
    }

    private func defaultTitle(for type: NoteType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())

        switch type {
        case .text: return "Text Note \(dateString)"
        case .audio: return "Audio Note \(dateString)"
        case .image: return "Image Note \(dateString)"
        case .pdf: return "PDF Note \(dateString)"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AudioRecorderView
struct AudioRecorderView: View {
    @ObservedObject var audioService: AudioService
    @Environment(\.dismiss) var dismiss
    var onSave: (Data?, String?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                // Recording visualization (placeholder)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))

                    if audioService.isRecording {
                        // Simple animation for recording
                        HStack(spacing: 4) {
                            ForEach(0..<10) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 20 + CGFloat.random(in: 0...40))
                                    .animation(
                                        Animation.easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(Double(i) * 0.05),
                                        value: audioService.isRecording
                                    )
                            }
                        }
                    } else {
                        Text("Tap Record to start recording")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 100)
                .padding()

                // Live transcription display
                if audioService.isRecording && !audioService.liveTranscription.isEmpty {
                    ScrollView {
                        Text(audioService.liveTranscription)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
                }

                // Recording time
                if audioService.isRecording {
                    Text(audioService.formatTime(audioService.recordingTime))
                        .font(.system(size: 54, weight: .thin, design: .monospaced))
                        .padding()
                }

                Spacer()

                // Recording controls
                HStack(spacing: 40) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                    }

                    Button {
                        if audioService.isRecording {
                            audioService.stopRecording()
                        } else {
                            audioService.startRecording()
                        }
                    } label: {
                        Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(audioService.isRecording ? .red : .accentColor)
                    }

                    Button {
                        // Save button only enabled when recording is stopped
                        onSave(nil, audioService.liveTranscription)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                    }
                    .disabled(audioService.isRecording)
                    .opacity(audioService.isRecording ? 0.5 : 1.0)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Record Audio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - AudioRecordingDelegate
extension CreateNoteView: AudioRecordingDelegate {
    func audioRecordingDidFinish(audioData: Data?, transcription: String?) {
        savedAudioData = audioData
        audioTranscript = transcription
    }

    func audioRecordingDidUpdateTranscription(text: String) {
        // Update live transcription if needed
    }

    func audioRecordingDidFail(with error: Error) {
        print("Audio recording failed: \(error)")
    }
}

#Preview {
    // Need a ModelContainer and AI Service for the preview
    @MainActor
    func previewContent() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: config)

        return CreateNoteView()
            .modelContainer(container)
            .environmentObject(AIServiceWrapper(service: MockAIService()))
    }

    return previewContent()
}
