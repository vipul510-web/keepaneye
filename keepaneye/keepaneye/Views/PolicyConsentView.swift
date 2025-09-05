import SwiftUI

struct PolicyConsentView: View {
    @ObservedObject var consent = ConsentManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to KeepAnEye")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Your privacy matters. Please review how we use data to improve the app.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    // Policy summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What we collect and why")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Usage analytics (app interactions, screens)", systemImage: "chart.bar.doc.horizontal")
                            Label("Crash diagnostics (error reports, device model)", systemImage: "exclamationmark.triangle")
                            Label("No personalized advertising", systemImage: "nosign")
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        
                        Link("Read full Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                            .font(.subheadline)
                    }
                    
                    // Toggles
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $consent.analyticsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share anonymous analytics")
                                Text("Helps us understand which features are useful.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Toggle(isOn: $consent.crashReportsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share crash reports")
                                Text("Helps us quickly fix bugs and improve stability.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Personalized ads: off and disabled, with explanatory copy
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding.constant(false)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Personalized ads")
                                    Text("We do not use personalized advertising in this app.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(true)
                            Text("Ads are disabled by design. We don't plan to show personalized ads.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: acceptAndContinue) {
                            Text("Accept and Continue")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: declineAndContinue) {
                            Text("Continue without sharing")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy & Consent")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func acceptAndContinue() {
        consent.hasCompletedConsent = true
        dismiss()
    }
    
    private func declineAndContinue() {
        consent.analyticsEnabled = false
        consent.crashReportsEnabled = false
        consent.personalizedAdsEnabled = false
        consent.hasCompletedConsent = true
        dismiss()
    }
}

#Preview {
    PolicyConsentView()
}


