#if os(iOS)
import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceBirthdayCapture: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?
    @Published var isAuthorized = false

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await requestMicrophone()
        isAuthorized = speechOK && micOK && (recognizer?.isAvailable ?? false)
        if !speechOK {
            errorMessage = "Speech recognition permission is required."
        } else if !micOK {
            errorMessage = "Microphone permission is required."
        } else if !(recognizer?.isAvailable ?? false) {
            errorMessage = "Speech recognition isn’t available right now."
        }
        return isAuthorized
    }

    func start() throws {
        errorMessage = nil
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn’t available."
            return
        }

        teardown(cancelRecognition: true)
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        self.transcript = text
                    }
                }

                if result?.isFinal == true {
                    self.finishRecognition()
                } else if let error {
                    let ns = error as NSError
                    let isCancel = ns.domain == "kAFAssistantErrorDomain" && (ns.code == 216 || ns.code == 203)
                    if !isCancel, self.transcript.isEmpty {
                        self.errorMessage = error.localizedDescription
                    }
                    self.finishRecognition()
                }
            }
        }
    }

    func stop() {
        guard isRecording || audioEngine.isRunning else { return }
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func discard() {
        teardown(cancelRecognition: true)
    }

    private func finishRecognition() {
        isRecording = false
        recognitionRequest = nil
        recognitionTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    private func teardown(cancelRecognition: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if cancelRecognition {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophone() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
    }
}
#endif
