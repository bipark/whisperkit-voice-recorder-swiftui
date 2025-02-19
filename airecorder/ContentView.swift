//
//  ContentView.swift
//  airecorder
//
//  Created by BillyPark on 1/14/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showingRecorder = false
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var showErrorAlert = false
    @State private var showingSettings = false
    @State private var errorMessage = ""
    @State private var selectedRecording: Recording?
    @StateObject private var audioTranscriber = AudioTranscriber.shared

    
    private var debounceTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    
    var groupedRecordings: [(String, [Recording])] {
        let grouped = Dictionary(grouping: filteredRecordings) { recording in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: recording.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var filteredRecordings: [Recording] {
        if debouncedSearchText.isEmpty {
            return audioRecorder.recordings
        } else {
            return DatabaseManager.shared.searchRecordings(query: debouncedSearchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .onReceive(debounceTimer) { _ in
                        debouncedSearchText = searchText
                    }
                
                List {
                    ForEach(groupedRecordings, id: \.0) { date, recordings in
                        Section(header: Text(formatDate(date))) {
                            ForEach(recordings, id: \.createdAt) { recording in
                                Button(action: {
                                    selectedRecording = recording
                                }) {
                                    RecordingRow(recording: recording)
                                }
                            }
                            .onDelete { indices in
                                indices.forEach { index in
                                    let recording = recordings[index]
                                    if let globalIndex = filteredRecordings.firstIndex(where: { $0.createdAt == recording.createdAt }) {
                                        deleteRecording(at: IndexSet([globalIndex]))
                                    }
                                }
                            }
                        }
                    }
                }
                
                Button(action: {
                    showingRecorder = true
                }) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle("l_main_title".localized)
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
            .background(
                NavigationLink(
                    destination: Group {
                        if let recording = selectedRecording {
                            PlayerView(recording: recording, audioRecorder: audioRecorder)
                        }
                    },
                    isActive: Binding(
                        get: { selectedRecording != nil },
                        set: { if !$0 { selectedRecording = nil } }
                    )
                ) { EmptyView() }
            )
            .sheet(isPresented: $showingRecorder) {
                RecorderView(audioRecorder: audioRecorder)
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay {
                if audioTranscriber.modelState == .downloading {
                    VStack {
                        ProgressView("l_downloading".localized, value: audioTranscriber.modelDownloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding()
                        Text("\(Int(audioTranscriber.modelDownloadProgress * 100))%")
                    }
                    .frame(width: 300)
                    .padding()
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }
            }

        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        if Calendar.current.isDateInToday(date) {
            return "l_today".localized
        } else if Calendar.current.isDateInYesterday(date) {
            return "l_yesterday".localized
        }
        
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }
    
    func deleteRecording(at indexSet: IndexSet) {
        for index in indexSet {
            let recording = filteredRecordings[index]
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: recording.fileURL.path) {
                    try fileManager.removeItem(at: recording.fileURL)
                    DatabaseManager.shared.deleteRecording(at: recording.fileURL.path)
                    audioRecorder.fetchRecordings()
                } else {
                    // If file is already gone, just clean up the database
                    DatabaseManager.shared.deleteRecording(at: recording.fileURL.path)
                    audioRecorder.fetchRecordings()
                }
            } catch {
                errorMessage = "l_delete_error".localized
                showErrorAlert = true
            }
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .lineLimit(1)
                
                HStack {
                    Text(formatTime(recording.createdAt))
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Spacer()
                    
                    if let duration = try? AVAudioPlayer(contentsOf: recording.fileURL).duration {
                        Text(timeString(duration))
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("l_search".localized, text: $text)
                .focused($isFocused)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            if isFocused {
                Button(action: {
                    isFocused = false
                }) {
                    Text("Done")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
