import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Last updated: September 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    // Policy Content
                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(title: "Information We Collect", content: """
                        We collect information you provide directly to us, such as:
                        • Account information (name, email, password)
                        • Child information (name, age, gender)
                        • Schedule and activity data
                        • Caregiver assignments and permissions
                        
                        We also collect usage analytics and crash reports to improve the app experience.
                        """)
                        
                        PolicySection(title: "How We Use Your Information", content: """
                        We use the information we collect to:
                        • Provide and maintain the KeepAnEye service
                        • Process your requests and transactions
                        • Send you technical notices and support messages
                        • Improve our app and develop new features
                        • Ensure the security and integrity of our service
                        """)
                        
                        PolicySection(title: "Data Sharing", content: """
                        We do not sell, trade, or rent your personal information to third parties.
                        
                        We may share information with:
                        • Service providers who help us operate the app
                        • Other users (caregivers) as authorized by you
                        • Law enforcement when required by law
                        
                        We do not use personalized advertising or track you across other apps or websites.
                        """)
                        
                        PolicySection(title: "Data Security", content: """
                        We implement appropriate security measures to protect your information:
                        • Encryption of data in transit and at rest
                        • Secure authentication and authorization
                        • Regular security assessments
                        • Access controls and monitoring
                        """)
                        
                        PolicySection(title: "Your Rights", content: """
                        You have the right to:
                        • Access and update your personal information
                        • Delete your account and associated data
                        • Opt out of analytics and crash reporting
                        • Request a copy of your data
                        • Contact us with privacy concerns
                        """)
                        
                        PolicySection(title: "Data Retention", content: """
                        We retain your information for as long as your account is active or as needed to provide services.
                        
                        When you delete your account, we will delete your personal information within 30 days, except where we are required to retain it for legal or security purposes.
                        """)
                        
                        PolicySection(title: "Children's Privacy", content: """
                        KeepAnEye is designed for parents and caregivers to manage children's information.
                        
                        We do not knowingly collect personal information from children under 13 without parental consent. Parents can control and delete their children's information at any time.
                        """)
                        
                        PolicySection(title: "Contact Us", content: """
                        If you have questions about this Privacy Policy, please contact us at:
                        
                        Email: privacy@keepaneye.com
                        Address: [Your Company Address]
                        
                        We will respond to your inquiry within 30 days.
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
