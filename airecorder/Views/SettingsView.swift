import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var transcriber = AudioTranscriber.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("selectedLanguage") private var selectedLanguage = "en" 
    @AppStorage("useICloud") private var useICloud = false
    
    @State private var showPurchaseSheet = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false

    
    let languages = [
        "en": "English",
        "ko": "한국어",
        "ja": "日本語",
        "zh": "Chinese",
        "de": "German",
        "es": "Spanish",
        "ru": "Russian",
        "fr": "French",
        "pt": "Portuguese",
        "tr": "Turkish",
        "pl": "Polish",
        "ar": "Arabic",
        "sv": "Swedish",
        "it": "Italian",
        "id": "Indonesian",
        "hi": "Hindi",
        "fi": "Finnish",
        "vi": "Vietnamese",
        "he": "Hebrew",
        "uk": "Ukrainian",
        "el": "Greek",
        "ms": "Malay",
        "cs": "Czech",
        "ro": "Romanian",
        "da": "Danish",
        "hu": "Hungarian",
        "ta": "Tamil",
        "no": "Norwegian",
        "th": "Thai"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("l_language".localized)) {
                    Picker("l_language".localized, selection: $selectedLanguage) {
                        ForEach(Array(languages.keys), id: \.self) { key in
                            Text(languages[key] ?? "")
                                .tag(key)
                        }
                    }
                }
                
                Section(header: Text("l_save_icloud".localized)) {
                    Toggle("l_save_icloud".localized, isOn: $useICloud)
                }
                
                Section(header: Text("l_app_info".localized)) {
                    HStack {
                        Text("l_contact_us".localized)
                        Spacer()
                        Link("email", destination: URL(string: "mailto://rtlink.park@gmail.com")!)
                    }
                    HStack {
                        Text("l_app_version".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.gray)
                    }
                }
                                
            }
            .navigationTitle("l_app_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("l_close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("l_info".localized),
                message: Text(alertMessage),
                dismissButton: .default(Text("l_ok".localized))
            )
        }
        .alert("l_error", isPresented: $showErrorAlert) {
            Button("l_ok", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }

    }
}
