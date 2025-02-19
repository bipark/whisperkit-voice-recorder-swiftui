import SwiftUI

struct TranscriptionView: View {
    @Binding var currentRecording: Recording
    @Binding var showCopiedToast: Bool
    @Binding var showEditDialog: Bool
    
    var body: some View {
        ScrollView {
            Spacer().frame(height: 4)
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("l_t_result".localized)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(currentRecording.content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .animation(.easeInOut, value: currentRecording.content)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = currentRecording.content
                            withAnimation {
                                showCopiedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        }) {
                            Label("l_copy".localized, systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            showEditDialog = true
                        }) {
                            Label("l_edit".localized, systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .padding(.trailing, 10)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}
