import SwiftUI

struct AddFeedItemView: View {
    let selectedChild: Child?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var selectedType: FeedContentType = .note
    @State private var title = ""
    @State private var content = ""
    @State private var selectedChildId = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Child") {
                    if let child = selectedChild {
                        HStack {
                            Text(child.gender.emoji)
                            Text(child.fullName)
                                .fontWeight(.medium)
                        }
                    } else {
                        Picker("Select Child", selection: $selectedChildId) {
                            ForEach(dataManager.children) { child in
                                HStack {
                                    Text(child.gender.emoji)
                                    Text(child.fullName)
                                }
                                .tag(child.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Content Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(FeedContentType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Content", text: $content, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5...10)
                }
                
                if selectedType != .note {
                    Section("Media") {
                        Button(action: { /* TODO: Add photo/video picker */ }) {
                            HStack {
                                Image(systemName: selectedType == .photo ? "photo" : "video")
                                Text("Add \(selectedType.displayName)")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Actions") {
                    Button(action: createFeedItem) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Post to Feed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || title.isEmpty || content.isEmpty || (selectedChild == nil && selectedChildId.isEmpty))
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Add Post")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createFeedItem() {
        isLoading = true
        
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        let childId = selectedChild?.id ?? selectedChildId
        
        let feedItem = FeedItem(
            childId: childId,
            title: title,
            content: content,
            contentType: selectedType,
            createdBy: currentUser.fullName
        )
        
        // In a real app, this would be saved to the backend
        // For now, we'll just dismiss the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    AddFeedItemView(selectedChild: nil)
        .environmentObject(DataManager())
        .environmentObject(AuthenticationManager())
} 