import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var dataManager = DataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                TabView(selection: $selectedTab) {
                    ScheduleView()
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("Schedule")
                        }
                        .tag(0)
                        .onTapGesture {
                            print("[Tab] Tapped Schedule tab")
                        }
                    
                    FeedView()
                        .tabItem {
                            Image(systemName: "newspaper")
                            Text("Notes")
                        }
                        .tag(1)
                        .onTapGesture {
                            print("[Tab] Tapped Feed tab")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.circle")
                            Text("Profile")
                        }
                        .tag(2)
                        .onTapGesture {
                            print("[Tab] Tapped Profile tab")
                        }
                }
                .accentColor(.blue)
                .onChange(of: selectedTab) { oldValue, newValue in
                    print("[Tab] Selection changed: \(oldValue) -> \(newValue)")
                }
                .onAppear {
                    // Load children from backend if user is authenticated
                    if authManager.isAuthenticated && authManager.currentUser != nil {
                        Task {
                            await dataManager.loadChildrenFromBackend()
                        }
                    }
                }
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .environmentObject(authManager)
        .environmentObject(dataManager)
    }
}

#Preview {
    ContentView()
} 