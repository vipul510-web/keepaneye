import SwiftUI
import Combine

struct FeedView: View {
    @State private var feedItems: [FeedItem] = []
    @State private var showingAddPost = false
    @State private var selectedChild: Child?
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    private var sortedFeedItems: [FeedItem] {
        feedItems.sorted { item1, item2 in
            if item1.isPinned && !item2.isPinned {
                return true
            } else if !item1.isPinned && item2.isPinned {
                return false
            } else {
                return item1.createdAt > item2.createdAt
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let selectedChild = selectedChild {
                    // Feed content for a specific child
                    VStack(spacing: 0) {
                        // Child name subtitle
                        VStack(spacing: 2) {
                            Text(selectedChild.fullName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground))
                        
                        // Feed content list
                        if feedItems.isEmpty {
                            EmptyFeedView(showingAddPost: $showingAddPost, child: selectedChild)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(sortedFeedItems) { item in
                                        FeedItemCard(feedItem: item)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                } else {
                    // No child selected: present child selection/add flow like home
                    ChildSelectionView(selectedChild: $selectedChild)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        print("[Feed] Tapped add note button")
                        showingAddPost = true 
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .disabled(selectedChild == nil)
                }
            }
            .sheet(isPresented: $showingAddPost) {
                SimpleAddFeedView(child: selectedChild)
                    .onDisappear {
                        // Refresh feed items when add note sheet is dismissed
                        loadFeedItems()
                    }
            }
            .onAppear {
                let accessibleChildren = authManager.getAccessibleChildren(dataManager: dataManager)
                if selectedChild == nil && accessibleChildren.count == 1 {
                    selectedChild = accessibleChildren.first
                }
                print("[Feed] onAppear - selectedChild=\(selectedChild?.fullName ?? "nil"), children=\(accessibleChildren.count)")
                loadFeedItems()
            }
            .onChange(of: selectedChild) { _, _ in
                loadFeedItems()
            }
        }
    }
    
    private func loadFeedItems() {
        guard let selectedChild = selectedChild else {
            // No child selected: do not show any items
            if !feedItems.isEmpty { feedItems = [] }
            print("[Feed] loadFeedItems skipped - no child selected")
            return
        }
        
        // Load feed items from backend
        Task {
            do {
                let backendFeedItems = try await APIClient.shared.getFeedItems(childId: selectedChild.id)
                await MainActor.run {
                    feedItems = backendFeedItems
                    print("[Feed] loadFeedItems - count=\(feedItems.count), selectedChild=\(selectedChild.fullName)")
                }
            } catch {
                print("❌ Failed to load feed items: \(error)")
                await MainActor.run {
                    feedItems = []
                }
            }
        }
    }
}

struct SimpleAddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Preselected child from parent view
    private let child: Child?
    
    @State private var title = ""
    @State private var content = ""
    @State private var isPinned = false
    @State private var selectedChild: Child?
    @State private var isLoading = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var contentType: FeedContentType = .note
    
    init(child: Child? = nil) {
        self.child = child
        self._selectedChild = State(initialValue: child)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Note")
                    .font(.title2)
                            .fontWeight(.bold)
                
                        Text("Share an update about your child")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Content Type Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                contentType = .note
                                selectedImage = nil
                            }) {
                                HStack {
                                    Image(systemName: "text.bubble")
                                    Text("Note")
                                }
                                .foregroundColor(contentType == .note ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(contentType == .note ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                contentType = .photo
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Photo")
                                }
                                .foregroundColor(contentType == .photo ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(contentType == .photo ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Content Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Share what happened...", text: $content, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(4...8)
                    }
                    
                    // Photo Preview
                    if let selectedImage = selectedImage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photo")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                                
                                Button(action: {
                                    self.selectedImage = nil
                                    contentType = .note
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                        }
                    }
                    
                    // Pin Option
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundColor(.orange)
                            Text("Pin to Top")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Toggle("", isOn: $isPinned)
                                .toggleStyle(SwitchToggleStyle(tint: .orange))
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        
                        if isPinned {
                            Text("This note will be highlighted and shown at the top")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Create Button
                    Button(action: createNote) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            Text("Create Note")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(title.isEmpty || content.isEmpty || selectedChild == nil ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(title.isEmpty || content.isEmpty || selectedChild == nil || isLoading)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Ensure we honor preselected child from parent
                if selectedChild == nil, let child = child {
                    selectedChild = child
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func createNote() {
        guard !title.isEmpty && !content.isEmpty, let child = selectedChild else { return }
        
        isLoading = true
        
        // Generate a mock image URL if photo is selected
        let mediaURLs = contentType == .photo && selectedImage != nil ? ["photo_\(UUID().uuidString).jpg"] : []
        
        Task {
            do {
                let request = CreateFeedItemRequest(
                    childId: child.id,
                    title: title,
                    content: content,
                    contentType: contentType.rawValue,
                    mediaURLs: mediaURLs,
                    isPinned: isPinned
                )
                
                let savedFeedItem = try await APIClient.shared.createFeedItem(request)
                print("✅ Created \(contentType.displayName): \(savedFeedItem.title) - Pinned: \(savedFeedItem.isPinned)")
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("❌ Failed to create feed item: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct FeedItemCard: View {
    let feedItem: FeedItem
    @State private var showingDetails = false
    @EnvironmentObject var authManager: AuthenticationManager
    
    private var authorDisplayName: String {
        if let user = authManager.currentUser, feedItem.createdBy == user.id {
            return user.displayName
        }
        return "Caregiver"
    }
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                        Text(authorDisplayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            
                            if feedItem.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(feedItem.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(feedItem.contentType.icon)
                        .font(.title2)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(feedItem.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(feedItem.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    if !feedItem.mediaURLs.isEmpty {
                        HStack {
                            Image(systemName: feedItem.contentType == .photo ? "photo" : "video")
                                .foregroundColor(.blue)
                            Text("\(feedItem.mediaURLs.count) \(feedItem.contentType == .photo ? "photo" : "video")\(feedItem.mediaURLs.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            .background(feedItem.isPinned ? Color.orange.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(feedItem.isPinned ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            SimpleFeedDetailView(feedItem: feedItem)
                .environmentObject(authManager)
        }
    }
}

struct SimpleFeedDetailView: View {
    let feedItem: FeedItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    private var authorDisplayName: String {
        if let user = authManager.currentUser, feedItem.createdBy == user.id {
            return user.displayName
        }
        return "Caregiver"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(feedItem.contentType.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text(feedItem.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(feedItem.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 10) {
                    Text("Posted by: \(authorDisplayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(feedItem.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Post Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EmptyFeedView: View {
    @Binding var showingAddPost: Bool
    let child: Child?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            if let child = child {
                Text("No posts for \(child.firstName) yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Share updates, photos, and videos about \(child.firstName)'s day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
            Text("No posts yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Share updates, photos, and videos about your child's day")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            
            Button(action: { showingAddPost = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Note")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding(.top, 100)
    }
}

// MARK: - Feed Item Model
struct FeedItem: Identifiable, Codable, Equatable {
    let id: String
    let childId: String
    let title: String
    let content: String
    let contentType: FeedContentType
    let mediaURLs: [String]
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    let isPinned: Bool
    
    init(id: String = UUID().uuidString,
         childId: String,
         title: String,
         content: String,
         contentType: FeedContentType,
         mediaURLs: [String] = [],
         createdBy: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         isPinned: Bool = false) {
        self.id = id
        self.childId = childId
        self.title = title
        self.content = content
        self.contentType = contentType
        self.mediaURLs = mediaURLs
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        childId = try container.decode(String.self, forKey: .childId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        
        let contentTypeString = try container.decode(String.self, forKey: .contentType)
        contentType = FeedContentType(rawValue: contentTypeString) ?? .note
        
        // Parse mediaURLs which may arrive as a native JSON array or a JSON-encoded string
        if let urls = try? container.decode([String].self, forKey: .mediaURLs) {
            mediaURLs = urls
        } else if let mediaURLsString = try? container.decode(String.self, forKey: .mediaURLs),
                  let data = mediaURLsString.data(using: .utf8),
                  let urls = try? JSONSerialization.jsonObject(with: data) as? [String] {
            mediaURLs = urls
        } else {
            mediaURLs = []
        }
        
        createdBy = try container.decode(String.self, forKey: .createdBy)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        
        // Parse dates
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid createdAt date format")
        }
        guard let updatedAt = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid updatedAt date format")
        }
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case title
        case content
        case contentType = "content_type"
        case mediaURLs = "media_urls"
        case createdBy = "created_by"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum FeedContentType: String, CaseIterable, Codable, Equatable {
    case note = "note"
    case photo = "photo"
    case video = "video"
    
    var displayName: String {
        switch self {
        case .note:
            return "Note"
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        }
    }
    
    var icon: String {
        switch self {
        case .note:
            return "📝"
        case .photo:
            return "📷"
        case .video:
            return "🎥"
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(DataManager())
        .environmentObject(AuthenticationManager())
} 