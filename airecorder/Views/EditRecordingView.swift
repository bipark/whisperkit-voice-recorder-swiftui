import SwiftUI

struct EditRecordingView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentRecording: Recording
    @State var editingName: String
    @State var editingContent: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("l_title".localized)) {
                    TextField("l_title".localized, text: $editingName)
                }
                
                Section(header: Text("l_content".localized)) {
                    TextEditor(text: $editingContent)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("l_edit".localized)
            .navigationBarItems(
                leading: Button("l_cancel".localized) {
                    dismiss()
                },
                trailing: Button("l_save".localized) {
                    DatabaseManager.shared.updateRecordingContentAndName(
                        id: currentRecording.id,
                        content: editingContent,
                        name: editingName
                    )
                    currentRecording = Recording(
                        id: currentRecording.id,
                        name: editingName,
                        fileURL: currentRecording.fileURL,
                        createdAt: currentRecording.createdAt,
                        content: editingContent
                    )
                    dismiss()
                }
            )
        }
    }
}
