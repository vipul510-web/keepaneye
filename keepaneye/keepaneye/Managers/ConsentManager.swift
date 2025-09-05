import Foundation
import Combine

class ConsentManager: ObservableObject {
    static let shared = ConsentManager()
    
    @Published var analyticsEnabled: Bool {
        didSet { UserDefaults.standard.set(analyticsEnabled, forKey: Keys.analyticsEnabled) }
    }
    
    @Published var crashReportsEnabled: Bool {
        didSet { UserDefaults.standard.set(crashReportsEnabled, forKey: Keys.crashEnabled) }
    }
    
    // We do not serve personalized ads. Keep this false and immutable in UI.
    @Published var personalizedAdsEnabled: Bool {
        didSet { UserDefaults.standard.set(personalizedAdsEnabled, forKey: Keys.adsEnabled) }
    }
    
    @Published var hasCompletedConsent: Bool {
        didSet { UserDefaults.standard.set(hasCompletedConsent, forKey: Keys.completed) }
    }
    
    @Published var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Keys.onboarding) }
    }
    
    private struct Keys {
        static let analyticsEnabled = "Consent.analyticsEnabled"
        static let crashEnabled = "Consent.crashReportsEnabled"
        static let adsEnabled = "Consent.personalizedAdsEnabled"
        static let completed = "Consent.completed"
        static let onboarding = "Consent.onboarding"
    }
    
    init() {
        // Defaults: analytics/crash on, ads off, not completed
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.analyticsEnabled) == nil {
            defaults.set(true, forKey: Keys.analyticsEnabled)
        }
        if defaults.object(forKey: Keys.crashEnabled) == nil {
            defaults.set(true, forKey: Keys.crashEnabled)
        }
        if defaults.object(forKey: Keys.adsEnabled) == nil {
            defaults.set(false, forKey: Keys.adsEnabled)
        }
        if defaults.object(forKey: Keys.completed) == nil {
            defaults.set(false, forKey: Keys.completed)
        }
        if defaults.object(forKey: Keys.onboarding) == nil {
            defaults.set(false, forKey: Keys.onboarding)
        }
        analyticsEnabled = defaults.bool(forKey: Keys.analyticsEnabled)
        crashReportsEnabled = defaults.bool(forKey: Keys.crashEnabled)
        personalizedAdsEnabled = defaults.bool(forKey: Keys.adsEnabled)
        hasCompletedConsent = defaults.bool(forKey: Keys.completed)
        hasSeenOnboarding = defaults.bool(forKey: Keys.onboarding)
    }
    
    func resetConsent() {
        analyticsEnabled = true
        crashReportsEnabled = true
        personalizedAdsEnabled = false
        hasCompletedConsent = false
        hasSeenOnboarding = false
    }
}


