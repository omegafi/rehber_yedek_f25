import SwiftUI

@main
struct RehberYedekApp: App {
    @StateObject private var contactsViewModel = ContactsViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isFirstRun") private var isFirstRun = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "tr"
    @AppStorage("isPremium") private var isPremium = false
    
    var body: some Scene {
        WindowGroup {
            if isFirstRun {
                OnboardingView()
            } else {
                TabView {
                    HomeView()
                        .tabItem {
                            Label("Ana Sayfa", systemImage: "house.fill")
                        }
                    
                    ExportView()
                        .tabItem {
                            Label("Yedekleme", systemImage: "arrow.up.doc.fill")
                        }
                    
                    ImportView()
                        .tabItem {
                            Label("İçe Aktarma", systemImage: "arrow.down.doc.fill")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Label("Ayarlar", systemImage: "gear")
                        }
                }
                .environmentObject(contactsViewModel)
                .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
    }
} 