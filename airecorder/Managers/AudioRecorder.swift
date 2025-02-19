import Foundation
import AVFoundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var recording = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioMeterLevel: Float = 0.0
    
    var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var elapsedTimeTimer: Timer?
    
    override init() {
        super.init()
        fetchRecordings()
    }
    
    func startRecording() {
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed set up")
        }
        
        stopTimers()
        
        let timestamp = Date().toString()
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "\(timestamp).wav"
        let fileURL = documentPath.appendingPathComponent(filename)
        
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        do {
            if let existingRecorder = audioRecorder {
                existingRecorder.stop()
                self.audioRecorder = nil
            }
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.record()
            recording = true
            
            elapsedTime = 0
            startTimers()
            
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
        }
    }
    
    private func stopTimers() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        meterTimer?.invalidate()
        meterTimer = nil
    }
    
    private func startTimers() {
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
        
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            let level = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalizedValue = (level + 160) / 160
            self?.audioMeterLevel = max(0, min(1, normalizedValue))
        }
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopTimers()
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTimers()
    }
    
    func stopRecording() {
        stopTimers()
        audioRecorder?.stop()
        
        if let url = audioRecorder?.url {
            let id = Int64(Date().timeIntervalSince1970)
            
            if UserDefaults.standard.bool(forKey: "useICloud") {
                do {
                    try saveToICloud(url: url, recordingId: id)
                } catch {
                    print("\(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchRecordings() {
        recordings = DatabaseManager.shared.getAllRecordings()
    }
    
    func deleteRecording(at indexSet: IndexSet) {
        for index in indexSet {
            let recording = recordings[index]
            do {
                try FileManager.default.removeItem(at: recording.fileURL)
                DatabaseManager.shared.deleteRecording(at: recording.relativePath)
                recordings.remove(at: index)
            } catch {
                print("\(error.localizedDescription)")
            }
        }
    }
    
    private func saveToICloud(url: URL, recordingId: Int64) throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            throw RecordingError.iCloudNotAvailable
        }
        
        let containerId = "iCloud.com.rtlink.ai-recorder"
        
        guard let iCloudURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerId) else {
            throw RecordingError.iCloudNotAvailable
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        let documentsURL = iCloudURL.appendingPathComponent("Documents")
        let aiRecorderURL = documentsURL.appendingPathComponent("ai_recorder")
        let dailyFolderURL = aiRecorderURL.appendingPathComponent(todayString)
                
        do {
            try FileManager.default.createDirectory(
                at: dailyFolderURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            dateFormatter.dateFormat = "HHmmss"
            let timeString = dateFormatter.string(from: Date())
            let fileName = "recording_\(recordingId)_\(timeString).wav"
            let fileURL = dailyFolderURL.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw RecordingError.fileNotFound
            }
            
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw RecordingError.fileNotAccessible
            }
            
            try FileManager.default.copyItem(at: url, to: fileURL)
            
        } catch {
            throw error
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            let fileURL = recorder.url
            let name = fileURL.deletingPathExtension().lastPathComponent
            
            let recording = Recording(name: name, fileURL: fileURL)
            if DatabaseManager.shared.saveRecording(recording) != nil {
                fetchRecordings()
            } else {
                print("Failed save ")
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("\(error.localizedDescription)")
        }
    }
}

extension Date {
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }
}

// Add error type
enum RecordingError: LocalizedError {
    case iCloudNotAvailable
    case fileNotFound
    case fileNotAccessible
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "Cannot save to iCloud. Please check iCloud settings."
        case .fileNotFound:
            return "Original file not found."
        case .fileNotAccessible:
            return "Original file not accessible."
        }
    }
}
