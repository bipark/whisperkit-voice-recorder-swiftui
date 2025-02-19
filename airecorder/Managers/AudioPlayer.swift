import SwiftUI
import AVFoundation

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var audioMeterLevel: Float = 0.0
    @Published var isSeeking = false
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var meterTimer: Timer?
    
    func startPlayback(audio: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: audio)
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            duration = audioPlayer?.duration ?? 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.isSeeking {
                    self.currentTime = self.audioPlayer?.currentTime ?? 0
                }
            }
            
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                player.updateMeters()
                let level = player.averagePower(forChannel: 0)
                let normalizedValue = (level + 160) / 160
                self.audioMeterLevel = max(0, min(1, normalizedValue))
            }
            
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        
        timer?.invalidate()
        timer = nil
        meterTimer?.invalidate()
        meterTimer = nil
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        
        timer?.invalidate()
        timer = nil
        meterTimer?.invalidate()
        meterTimer = nil
    }
    
    func play() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer?.play()
            isPlaying = true
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.isSeeking {
                    self.currentTime = self.audioPlayer?.currentTime ?? 0
                }
            }
            
            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                player.updateMeters()
                let level = player.averagePower(forChannel: 0)
                let normalizedValue = (level + 160) / 160
                self.audioMeterLevel = max(0, min(1, normalizedValue))
            }
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func preparePlayback(audio: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audio)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            setupAudioMeter()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            isPlaying = false
        } catch {
            print("\(error)")
        }
    }
    
    func setupAudioMeter() {
        audioPlayer?.isMeteringEnabled = true
    }
    
    func seek(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
    }
    
    deinit {
        if let player = audioPlayer {
            player.stop()
            self.currentTime = 0
            self.timer?.invalidate()
            self.timer = nil
            self.meterTimer?.invalidate()
            self.meterTimer = nil
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished")
    }
}
