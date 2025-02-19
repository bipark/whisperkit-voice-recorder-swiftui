import SwiftUI

struct RecorderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var audioRecorder: AudioRecorder
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 120))
                .foregroundColor(audioRecorder.isPaused ? .blue : .red)
            Spacer()
            
            Text(formatTime(audioRecorder.elapsedTime))
                .font(.system(size: 54, weight: .medium))
                .foregroundColor(audioRecorder.isPaused ? .blue : .red)
                .monospacedDigit()
                .padding(.top, 40)
            
            WaveformView(level: audioRecorder.audioMeterLevel)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            Spacer()
            
            HStack(spacing: 40) {
                // Pause/Resume button
                Button(action: {
                    if audioRecorder.isPaused {
                        audioRecorder.resumeRecording()
                    } else {
                        audioRecorder.pauseRecording()
                    }
                }) {
                    Image(systemName: audioRecorder.isPaused ? "mic.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                }
                
                // Stop button
                Button(action: {
                    audioRecorder.stopRecording()
                    dismiss()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            audioRecorder.startRecording()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
