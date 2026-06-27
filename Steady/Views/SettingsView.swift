import SwiftUI

struct SettingsView: View {
    @Bindable var store: HabitStore
    @State private var showPremiumSheet = false
    @State private var showTimePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Notifications
                Section("Notifications") {
                    Toggle(isOn: Binding(
                        get: { NotificationManager.shared.isEnabled },
                        set: { NotificationManager.shared.isEnabled = $0 }
                    )) {
                        Label("Activer les rappels", systemImage: "bell.fill")
                    }
                    
                    if NotificationManager.shared.isEnabled {
                        Button {
                            showTimePicker = true
                        } label: {
                            HStack {
                                Label("Heure du rappel", systemImage: "clock")
                                Spacer()
                                Text(NotificationManager.shared.dailyReminderTime, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Description du niveau de notification selon le statut
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: store.storeManager.isPremium ? "checkmark.seal.fill" : "bell.badge")
                                .foregroundStyle(Color.steadySage)
                                .font(.caption)
                            
                            Text(store.storeManager.isPremium
                                 ? "Premium : Rappels par habitude, résumé hebdomadaire et alerts de streak."
                                 : "Gratuit : Un rappel quotidien global à l'heure choisie.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Premium
                Section("Premium") {
                    if store.storeManager.isPremium {
                        HStack {
                            Label("Statut", systemImage: "checkmark.seal.fill")
                            Spacer()
                            Text("Actif")
                                .foregroundStyle(Color.steadySage)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Button {
                            showPremiumSheet = true
                        } label: {
                            Label("Passer à Premium", systemImage: "sparkles")
                                .foregroundStyle(Color.steadySage)
                        }
                        
                        Text("Débloquez les rappels par habitude, les statistiques avancées et l'illimité.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        Task {
                            await store.storeManager.restorePurchases()
                        }
                    } label: {
                        Label("Restaurer les achats", systemImage: "arrow.counterclockwise")
                    }
                }
                
                // MARK: - App
                Section("Application") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link("Politique de confidentialité", destination: AppLinks.privacyPolicy)
                    Link("Conditions d'utilisation", destination: AppLinks.termsOfUse)
                }
            }
            .navigationTitle("Paramètres")
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView(storeManager: store.storeManager)
            }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(time: Binding(
                    get: { NotificationManager.shared.dailyReminderTime },
                    set: { newTime in
                        NotificationManager.shared.dailyReminderTime = newTime
                        NotificationManager.shared.rescheduleAll(premium: store.storeManager.isPremium)
                    }
                ))
            }
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Binding var time: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Heure du rappel", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Heure du rappel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
        }
    }
}


