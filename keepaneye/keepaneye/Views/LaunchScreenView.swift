import SwiftUI

struct LaunchScreenView: View {
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo & Branding
            VStack(spacing: 20) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("KeepAnEye")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Childcare made simple")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // App Description
            VStack(spacing: 16) {
                Text("Track feeding, diaper changes, sleep, and activities for your little ones. Share schedules with caregivers and keep everyone in sync.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 8) {
                    Label("Create daily routines", systemImage: "calendar")
                    Label("Share with caregivers", systemImage: "person.2")
                    Label("Track important moments", systemImage: "heart")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Privacy Policy Link
            VStack(spacing: 12) {
                Button(action: { showingPrivacyPolicy = true }) {
                    Text("Privacy Policy")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                }
                
                Text("By using this app, you agree to our Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .fullScreenCover(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
}

#Preview {
    LaunchScreenView()
}
