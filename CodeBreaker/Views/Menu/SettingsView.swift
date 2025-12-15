import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @EnvironmentObject var livesManager: LivesManager
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("colorblindMode") private var colorblindMode = false

    @State private var showingResetAlert = false
    @State private var showingTimePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundTop")
                    .ignoresSafeArea()
                
                List {
                    // Game Settings
                    Section {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                        }
                        .onChange(of: hapticsEnabled) { _, newValue in
                            HapticManager.setEnabled(newValue)
                            if newValue {
                                HapticManager.shared.impact(.medium)
                            }
                        }
                        
                        Toggle(isOn: $soundEnabled) {
                            Label("Sound Effects", systemImage: "speaker.wave.2")
                        }
                        .onChange(of: soundEnabled) { _, newValue in
                            SoundManager.setEnabled(newValue)
                            if newValue {
                                SoundManager.shared.buttonTap()
                            }
                        }
                        
                        Toggle(isOn: $colorblindMode) {
                            Label("Colorblind Mode", systemImage: "eye")
                        }
                    } header: {
                        Text("Game Settings")
                    }

                    // Notifications
                    Section {
                        Toggle(isOn: $notificationManager.notificationsEnabled) {
                            Label("Daily Reminders", systemImage: "bell.badge")
                        }
                        .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
                            if newValue && !notificationManager.isAuthorized {
                                notificationManager.requestAuthorization()
                            }
                        }

                        if notificationManager.notificationsEnabled {
                            Button(action: {
                                showingTimePicker = true
                            }) {
                                HStack {
                                    Label("Reminder Time", systemImage: "clock")
                                    Spacer()
                                    Text(notificationManager.formattedReminderTime)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if !notificationManager.isAuthorized && notificationManager.notificationsEnabled {
                            Button(action: {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }) {
                                Label("Enable in Settings", systemImage: "gear")
                                    .foregroundColor(.orange)
                            }
                        }
                    } header: {
                        Text("Notifications")
                    } footer: {
                        Text("Get daily brain training reminders with fun messages to keep your streak alive!")
                    }

                    // Game Center
                    Section {
                        Button(action: {
                            gameCenterManager.showLeaderboards()
                        }) {
                            Label("Leaderboards", systemImage: "list.number")
                        }
                        
                        Button(action: {
                            gameCenterManager.showAchievements()
                        }) {
                            Label("Achievements", systemImage: "trophy")
                        }
                        
                        HStack {
                            Label("Status", systemImage: "gamecontroller")
                            Spacer()
                            Text(gameCenterManager.isAuthenticated ? "Connected" : "Not Connected")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Game Center")
                    }
                    
                    // Stats
                    Section {
                        HStack {
                            Label("Total Stars", systemImage: "star.fill")
                            Spacer()
                            Text("\(gameManager.totalStars)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Levels Completed", systemImage: "checkmark.circle")
                            Spacer()
                            Text("\(gameManager.levelsCompleted)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Current Streak", systemImage: "flame")
                            Spacer()
                            Text("\(gameManager.currentStreak) days")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Longest Streak", systemImage: "flame.fill")
                            Spacer()
                            Text("\(gameManager.longestStreak) days")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }

                    // Lives
                    Section {
                        HStack {
                            Label("Lives", systemImage: "heart.fill")
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(0..<LivesManager.maxLives, id: \.self) { index in
                                    Image(systemName: index < livesManager.lives ? "heart.fill" : "heart")
                                        .foregroundColor(index < livesManager.lives ? Color("PegRed") : .gray)
                                        .font(.caption)
                                }
                            }
                        }

                        if let timeString = livesManager.formattedTimeUntilNextLife {
                            HStack {
                                Label("Next Life", systemImage: "clock")
                                Spacer()
                                Text(timeString)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        #if DEBUG
                        Button(action: {
                            livesManager.debugSetLives(0)
                        }) {
                            Label("Debug: Set 0 Lives", systemImage: "heart.slash")
                        }

                        Button(action: {
                            livesManager.debugResetLives()
                        }) {
                            Label("Debug: Refill Lives", systemImage: "heart.fill")
                        }
                        #endif
                    } header: {
                        Text("Lives")
                    } footer: {
                        Text("Lives regenerate every 30 minutes. Watch ads to get extra lives instantly.")
                    }

                    // About
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        // Note: Update these URLs before release
                        if let privacyURL = URL(string: "https://example.com/privacy") {
                            Link(destination: privacyURL) {
                                Label("Privacy Policy", systemImage: "hand.raised")
                            }
                            .disabled(true)
                            .opacity(0.5)
                        }

                        if let termsURL = URL(string: "https://example.com/terms") {
                            Link(destination: termsURL) {
                                Label("Terms of Service", systemImage: "doc.text")
                            }
                            .disabled(true)
                            .opacity(0.5)
                        }
                    } header: {
                        Text("About")
                    }
                    
                    // Danger Zone
                    Section {
                        Button(role: .destructive, action: {
                            showingResetAlert = true
                        }) {
                            Label("Reset All Progress", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Data")
                    } footer: {
                        Text("This will permanently delete all your progress, including completed levels and achievements.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Progress?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    gameManager.resetAllProgress()
                    HapticManager.shared.notification(.warning)
                }
            } message: {
                Text("This will delete all your progress. This action cannot be undone.")
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerSheet(
                    hour: $notificationManager.reminderHour,
                    minute: $notificationManager.reminderMinute
                )
            }
        }
    }
}

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTime: Date

    init(hour: Binding<Int>, minute: Binding<Int>) {
        _hour = hour
        _minute = minute
        // Initialize with the current values
        var components = DateComponents()
        components.hour = hour.wrappedValue
        components.minute = minute.wrappedValue
        _selectedTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()

                Text("We'll send you a fun reminder at this time each day")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        hour = components.hour ?? 19
                        minute = components.minute ?? 0
                        HapticManager.shared.notification(.success)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .environmentObject(GameManager())
        .environmentObject(GameCenterManager())
        .environmentObject(LivesManager.shared)
}
