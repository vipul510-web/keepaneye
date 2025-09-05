import SwiftUI

struct FeedItemDetailView: View {
    let feedItem: FeedItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var newComment = ""
    @State private var comments: [Comment] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feedItem.createdBy)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(feedItem.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(feedItem.contentType.icon)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(feedItem.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(feedItem.content)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if !feedItem.mediaURLs.isEmpty {
                            HStack {
                                Image(systemName: feedItem.contentType == .photo ? "photo" : "video")
                                    .foregroundColor(.blue)
                                Text("\(feedItem.mediaURLs.count) \(feedItem.contentType == .photo ? "photo" : "video")\(feedItem.mediaURLs.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Comments
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Comments")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if comments.isEmpty {
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else {
                            ForEach(comments) { comment in
                                CommentView(comment: comment)
                            }
                        }
                        
                        // Add comment
                        VStack(spacing: 10) {
                            TextField("Add a comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                            
                            Button(action: addComment) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane")
                                    }
                                    Text("Post Comment")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isLoading || newComment.isEmpty)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding()
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
            .onAppear {
                loadComments()
            }
        }
    }
    
    private func loadComments() {
        // In a real app, this would load from the backend
        comments = [
            Comment(
                id: "1",
                content: "That's wonderful! Emma is growing so fast.",
                createdBy: "Jane Smith",
                createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
            ),
            Comment(
                id: "2",
                content: "Great to see her enjoying healthy foods!",
                createdBy: "John Doe",
                createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date()
            )
        ]
    }
    
    private func addComment() {
        guard let currentUser = authManager.currentUser, !newComment.isEmpty else { return }
        
        isLoading = true
        
        let comment = Comment(
            content: newComment,
            createdBy: currentUser.fullName
        )
        
        comments.insert(comment, at: 0)
        newComment = ""
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}

struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.createdBy)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(comment.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String = UUID().uuidString,
         content: String,
         createdBy: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

#Preview {
    FeedItemDetailView(feedItem: FeedItem(
        childId: "child1",
        title: "Great day at the park!",
        content: "Emma had so much fun playing on the swings and slides. She's getting so confident with climbing!",
        contentType: .note,
        createdBy: "John Doe"
    ))
    .environmentObject(DataManager())
    .environmentObject(AuthenticationManager())
} 