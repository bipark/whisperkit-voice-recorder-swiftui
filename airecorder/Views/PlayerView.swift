import SwiftUI
import AVFoundation

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriber = AudioTranscriber.shared
    @ObservedObject var audioRecorder: AudioRecorder
    
    @State private var showingSettings = false
    @State private var showPurchaseSheet = false
    @State private var showShareSheet = false
    @State private var showLoadingAlert = false
    @State private var showErrorAlert = false
    @State private var showEditDialog = false
    @State private var showCopiedToast = false
    @State private var showTranscriptionProgress = false
    @State private var transcriptionProgress: Double = 0.0
    @State private var errorMessage = ""
    @State private var loadingError: Error?
    
    let recording: Recording
    @State private var currentRecording: Recording
    
    // 프로그레스 뷰 크기 상수
    private let dialogWidth: CGFloat = 280
    private let dialogHeight: CGFloat = 180
    
    init(recording: Recording, audioRecorder: AudioRecorder) {
        self.recording = recording
        self.audioRecorder = audioRecorder
        _currentRecording = State(initialValue: recording)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 4)
                VStack(spacing: 12) {
                    WaveformView(level: audioPlayer.audioMeterLevel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .clipped()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    VStack(spacing: 20) {
                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                            Spacer()
                            Text(formatTime(audioPlayer.duration))
                        }
                        .font(.caption)
                        
                        Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                            if !editing {
                                audioPlayer.currentTime = audioPlayer.currentTime
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: backward15) {
                                Image(systemName: "gobackward.15")
                                    .font(.title)
                            }
                            Spacer()
                            Button(action: playPause) {
                                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                            }
                            Spacer()
                            Button(action: forward15) {
                                Image(systemName: "goforward.15")
                                    .font(.title)
                            }
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                Task {
                                    await transcribe()
                                }
                            }) {
                                Text("l_transcribe".localized)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(transcriber.isTranscribing)
                            
                            Button(action: shareAudioFile) {
                                Text("l_share_file".localized)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.vertical)
                    }
                    .padding(.horizontal)
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                Divider()
                
                TranscriptionView(
                    currentRecording: $currentRecording,
                    showCopiedToast: $showCopiedToast,
                    showEditDialog: $showEditDialog
                )
            }
            
            if showCopiedToast {
                VStack {
                    Text("l_copied".localized)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .transition(.opacity)
                .animation(.easeInOut)
            }
            
            if showTranscriptionProgress {
                // 반투명 배경
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                // 고정 크기의 다이얼로그
                VStack(spacing: 20) {
                    let progressText: String = {
                        switch transcriber.modelState {
                        case .downloading:
                            return "l_down_model".localized
                        case .loading:
                            return "l_load_model".localized
                        default:
                            return "l_working".localized
                        }
                    }()
                    
                    ProgressView(progressText)
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    if transcriber.modelState == .downloading {
                        VStack(spacing: 8) {
                            // 프로그레스 그래프
                            ProgressGraphView(level: transcriber.modelDownloadProgress)
                                .frame(height: 4)
                                .animation(.linear(duration: 0.1), value: transcriber.modelDownloadProgress)
                            
                            Text("\(Int(transcriber.modelDownloadProgress * 100))%")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .frame(width: dialogWidth * 0.8)
                    }
                    
                    if transcriber.isTranscribing {
                        Button(action: {
                            transcriber.cancelTranscription()
                            showTranscriptionProgress = false
                        }) {
                            Text("l_cancel".localized)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .frame(width: dialogWidth, height: dialogHeight)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
        .navigationTitle(currentRecording.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.footnote)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [recording.fileURL])
        }
        .alert("l_error".localized, isPresented: $showLoadingAlert) {
            Button("l_ok".localized, role: .cancel) { }
        } message: {
            if let error = loadingError {
                Text(error.localizedDescription)
            }
        }
        .alert("l_error", isPresented: $showErrorAlert) {
            Button("l_ok", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEditDialog) {
            EditRecordingView(
                currentRecording: $currentRecording,
                editingName: currentRecording.name,
                editingContent: currentRecording.content
            )
        }
        .onAppear {
            audioPlayer.startPlayback(audio: recording.fileURL)
        }
        .onDisappear {
            audioPlayer.stop()
            audioRecorder.fetchRecordings()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func backward15() {
        audioPlayer.seek(by: -15)
    }
    
    private func forward15() {
        audioPlayer.seek(by: 15)
    }
    
    private func playPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }
    
    private func shareAudioFile() {
        showShareSheet = true
    }
    
    private func transcribe() async {
        do {
            showTranscriptionProgress = true
            transcriptionProgress = 0.0
            try await transcriber.initializeWhisperKitIfNeeded()
            let result = try await transcriber.transcribeAudio(from: recording.fileURL)
                        
            await MainActor.run {
                showTranscriptionProgress = false
                let firstRow = result.components(separatedBy: .newlines).first ?? ""
                let title = firstRow.replacingOccurrences(of: "00:00", with: "").trimmingCharacters(in:.whitespaces)
                
                if !result.isEmpty {
                    DatabaseManager.shared.updateRecordingContentAndName(
                        id: recording.id,
                        content: result,
                        name: title
                    )
                    
                    currentRecording = Recording(
                        id: currentRecording.id,
                        name: title,
                        fileURL: currentRecording.fileURL,
                        content: result
                    )
                    
                    audioRecorder.fetchRecordings()
                }
            }
        } catch {
            loadingError = error
            showLoadingAlert = true
            showTranscriptionProgress = false
        }
    }    
}

// Wrapper for using UIActivityViewController in SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 프로그레스 그래프 뷰
struct ProgressGraphView: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 배경
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                
                // 진행 상태
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(0, min(geometry.size.width * CGFloat(level), geometry.size.width)))
            }
        }
    }
}
