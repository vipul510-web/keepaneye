import SwiftUI

@main
struct KeepAnEyeApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var dataManager = DataManager()
    @StateObject private var consentManager = ConsentManager.shared
    @State private var showingLaunchScreen = true
    @State private var showingOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(dataManager)
                .environmentObject(consentManager)
                                        .fullScreenCover(isPresented: $showingLaunchScreen) {
                            LaunchScreenView()
                                .onAppear {
                                    // Auto-dismiss after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        showingLaunchScreen = false
                                        // Show onboarding only for non-logged-in users
                                        if !authManager.isAuthenticated {
                                            showingOnboarding = true
                                        }
                                    }
                                }
                        }
                                        .fullScreenCover(isPresented: $showingOnboarding) {
                            OnboardingView()
                                .onDisappear {
                                    // No need to track onboarding completion since it's shown based on auth status
                                    // Users will see onboarding every time they're not logged in
                                }
                        }
        }
    }
} 

