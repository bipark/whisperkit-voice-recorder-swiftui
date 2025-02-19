import Foundation
import WhisperKit
import AVFoundation
import CoreML
import SwiftUI

enum TranscriptionError: Error {
    case notInitialized
    case invalidAudioFormat
    case transcriptionFailed
}

@MainActor
class AudioTranscriber: ObservableObject {
    static let shared = AudioTranscriber()
    
    @Published var isTranscribing: Bool = false
    @Published var modelState: ModelState = .unloaded
    @Published var modelDownloadProgress: Float = 0.0
    
    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<String, Error>?
    private var isCancelled: Bool = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    
    private var modelConfig: (name: String, storage: String) {
        let deviceModel = getDeviceModel()
        
        switch deviceModel {
        case "iPhone SE (1st generation)", "iPhone SE (2nd generation)", "iPhone SE (3rd generation)",
             "iPad 9th gen", "iPad 10th gen", "iPad mini 6th gen":
            return ("whisper-tiny", "huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-tiny")
            
        case "iPhone 11", "iPhone 12", "iPhone 13",
             "iPad Air 4th gen":
            return ("whisper-base", "huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base")
            
        case "iPad Pro 12.9-inch 5th gen", "iPad Pro 12.9-inch 6th gen",
             "iPad Pro 11-inch 3rd gen", "iPad Pro 11-inch 4th gen",
             "iPad Air 5th gen":
            return ("whisper-small", "huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-small")
            
        default:
            if isLowerThaniPhone14() {
                return ("whisper-base", "huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base")
            } else {
                return ("whisper-small", "huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-small")
            }
        }
    }
    
    private var repoName: String {
        "argmaxinc/whisperkit-coreml"
    }
    
    func initializeWhisperKitIfNeeded() async throws {
        if whisperKit != nil {
            return
        }
        
        do {
            let containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let modelFolder = containerURL.appendingPathComponent(modelConfig.storage).path
            
            let fileManager = FileManager.default
            let modelExists = fileManager.fileExists(atPath: "\(modelFolder)/MelSpectrogram.mlmodelc")
            
            if !modelExists {
                modelState = .downloading
                try await downloadModel()
            }
            
            modelState = .loading
            
            let computeOptions: ModelComputeOptions
            if isLowerThaniPhone14() {
                computeOptions = ModelComputeOptions(
                    audioEncoderCompute: .cpuOnly,
                    textDecoderCompute: .cpuOnly
                )
            } else {
                computeOptions = ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                )
            }
            
            let config = WhisperKitConfig(
                modelFolder: modelFolder,
                computeOptions: computeOptions,
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: true,
                download: false
            )
            
            whisperKit = try await WhisperKit(config)
            
            try await withTimeout(seconds: 30) { [self] in
                try await self.whisperKit?.loadModels()
            }
            
            modelState = .loaded
        } catch {
            modelState = .failed
            throw error
        }
    }
    
    func downloadModel() async throws {
        modelState = .downloading
        
        do {
            let containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let modelFolder = containerURL.appendingPathComponent(modelConfig.storage).path
            
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: modelFolder) {
                try fileManager.createDirectory(atPath: modelFolder, withIntermediateDirectories: true)
            }
            
            _ = try await WhisperKit.download(
                variant: modelConfig.name,
                from: repoName,
                progressCallback: { progress in
                    Task { @MainActor in
                        self.modelDownloadProgress = Float(progress.fractionCompleted)
                    }
                }
            )
            
            modelState = .loaded
        } catch {
            modelState = .unloaded
            throw error
        }
    }
    
    func transcribeAudio(from url: URL) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.notInitialized
        }
        
        isCancelled = false
        isTranscribing = true
        
        do {
            transcriptionTask = Task {
                let audioSamples = try await Task {
                    try autoreleasepool {
                        try AudioProcessor.loadAudioAsFloatArray(fromPath: url.path)
                    }
                }.value
                
                if Task.isCancelled || isCancelled { throw CancellationError() }
                
                let options = DecodingOptions(
                    verbose: true,
                    task: .transcribe,
                    language: selectedLanguage,
                    temperature: 0.0,
                    sampleLength: 224,
                    wordTimestamps: true,
                    suppressBlank: false,
                    supressTokens: []
                )
                
                
                let result = try await whisperKit.transcribe(
                    audioArray: audioSamples,
                    decodeOptions: options
                )
                
                if Task.isCancelled || isCancelled { throw CancellationError() }
                
                if let transcription = result.first {
                    let formattedText = transcription.segments.map { segment in
                        let minutes = Int(segment.start) / 60
                        let seconds = Int(segment.start) % 60
                        let cleanText = segment.text
                            .replacingOccurrences(of: "<\\|[^>]+\\|>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespaces)
                        return String(format: "%02d:%02d  %@\n", minutes, seconds, cleanText)
                    }.joined(separator: "\n")
                    
                    return formattedText
                }
                return ""
            }
            
            let result = try await transcriptionTask?.value ?? ""
            isTranscribing = false
            return result
        } catch is CancellationError {
            isTranscribing = false
            return ""
        } catch {
            isTranscribing = false
            throw error
        }
    }
    
    func cancelTranscription() {
        isCancelled = true
        transcriptionTask?.cancel()
        Task { @MainActor in
            isTranscribing = false
        }
    }
}

enum ModelState {
    case unloaded
    case downloading
    case loading
    case loaded
    case failed
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "Timeout", code: -1, userInfo: nil)
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
