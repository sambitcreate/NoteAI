import Foundation
import AVFoundation
import Speech

// Protocol for audio recording delegate
protocol AudioRecordingDelegate {
    func audioRecordingDidFinish(audioData: Data?, transcription: String?)
    func audioRecordingDidUpdateTranscription(text: String)
    func audioRecordingDidFail(with error: Error)
}

class AudioService: NSObject, ObservableObject {
    // Published properties for UI updates
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var liveTranscription: String = ""

    // Audio recording properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var recordingTimer: Timer?

    // Speech recognition properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    // Delegate
    var delegate: AudioRecordingDelegate?

    override init() {
        super.init()
        setupSpeechRecognizer()
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized: \(status)")
                    self?.delegate?.audioRecordingDidFail(with: NSError(domain: "AudioService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }

    // MARK: - Recording Functions

    func startRecording() {
        // Check and request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self?.setupRecordingSession()
                } else {
                    print("Microphone permission denied")
                    self?.delegate?.audioRecordingDidFail(with: NSError(domain: "AudioService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]))
                }
            }
        }
    }

    private func setupRecordingSession() {
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create recording URL in temp directory
            let documentsPath = FileManager.default.temporaryDirectory
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            recordingURL = audioFilename

            // Configure recorder settings
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Create and start recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            if audioRecorder?.record() == true {
                isRecording = true
                recordingTime = 0
                liveTranscription = ""

                // Start timer to update recording time
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.recordingTime += 0.1
                }

                // Start speech recognition
                startSpeechRecognition()
            } else {
                delegate?.audioRecordingDidFail(with: NSError(domain: "AudioService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]))
            }
        } catch {
            print("Recording setup failed: \(error)")
            delegate?.audioRecordingDidFail(with: error)
        }
    }

    func stopRecording() {
        // Stop audio recorder
        audioRecorder?.stop()
        audioRecorder = nil

        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop speech recognition
        stopSpeechRecognition()

        isRecording = false

        // Get recorded audio data
        if let url = recordingURL, let audioData = try? Data(contentsOf: url) {
            delegate?.audioRecordingDidFinish(audioData: audioData, transcription: liveTranscription)
        } else {
            delegate?.audioRecordingDidFinish(audioData: nil, transcription: liveTranscription)
        }
    }

    // MARK: - Playback Functions

    func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio playback failed: \(error)")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Speech Recognition

    private func startSpeechRecognition() {
        // Initialize audio engine and speech recognition
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine,
              let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create speech recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio engine input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        do {
            try audioEngine.start()

            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.liveTranscription = transcription
                    self.delegate?.audioRecordingDidUpdateTranscription(text: transcription)
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.audioEngine?.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                }
            }
        } catch {
            print("Audio engine start failed: \(error)")
            stopSpeechRecognition()
        }
    }

    private func stopSpeechRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Helper Functions

    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }

    func getDuration(from audioData: Data) -> TimeInterval? {
        do {
            let tempPlayer = try AVAudioPlayer(data: audioData)
            return tempPlayer.duration
        } catch {
            print("Error getting audio duration: \(error)")
            return nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            delegate?.audioRecordingDidFail(with: NSError(domain: "AudioService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Recording finished unsuccessfully"]))
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            delegate?.audioRecordingDidFail(with: error)
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Handle playback finished
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio player error: \(error)")
        }
    }
}
