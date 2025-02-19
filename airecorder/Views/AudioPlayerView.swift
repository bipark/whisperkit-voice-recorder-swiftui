import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var transcriber: AudioTranscriber
    @Binding var showPurchaseSheet: Bool
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String
    let transcribeAction: () async -> Void
    let audioURL: URL
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                    if !editing {
                        audioPlayer.currentTime = audioPlayer.currentTime
                    }
                }
                
                Text("-" + formatTime(audioPlayer.duration - audioPlayer.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    audioPlayer.seek(by: -10)
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                
                Button(action: {
                    audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                
                Button(action: {
                    audioPlayer.seek(by: 10)
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        await transcribeAction()
                    }
                }) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [audioURL])
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
