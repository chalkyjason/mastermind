import Foundation
import UserNotifications

// MARK: - Notification Manager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published Properties

    @Published private(set) var isAuthorized: Bool = false
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            if notificationsEnabled {
                scheduleNotifications()
            } else {
                cancelAllNotifications()
            }
        }
    }

    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.reminderHour)
            if notificationsEnabled {
                scheduleNotifications()
            }
        }
    }

    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: Keys.reminderMinute)
            if notificationsEnabled {
                scheduleNotifications()
            }
        }
    }

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let lastPlayedDate = "lastPlayedDate"
    }

    private enum NotificationID {
        static let dailyReminder = "dailyReminder"
        static let streakAtRisk = "streakAtRisk"
        static let winBack = "winBack"
    }

    // MARK: - Funny Messages

    private let dailyReminderMessages: [(title: String, body: String)] = [
        ("Your neurons called", "They're bored. Time for some puzzles!"),
        ("Brain Bulletin", "Your brain cells are doing crossword puzzles without you."),
        ("Breaking News", "Your IQ misses you. Come back and show it some love."),
        ("Plot Twist Alert", "The code won't crack itself. Well, maybe it will... but that's no fun."),
        ("Official Complaint", "Your prefrontal cortex filed a complaint. Something about neglect?"),
        ("Roses are red...", "Violets are blue, your brain needs exercise, and so do you."),
        ("Lonely Code Alert", "The secret code is getting lonely. It's been talking to itself."),
        ("Warning", "Brain rust detected. Play now to lubricate those neurons."),
        ("Quick Question", "If a puzzle falls in a forest and no one solves it... is it still fun? Yes. Play now."),
        ("Science Fact*", "Playing Code Breaker makes you 47% more attractive.* (*Not scientifically proven)"),
        ("Your Brain Called", "It wants to feel smart again. Help it out?"),
        ("Achievement Unlocked", "Just kidding. You need to actually play first."),
        ("Friendly Reminder", "Your phone has more games than just doom-scrolling. Like this one!"),
        ("Brain Gym", "Skip leg day, never skip brain day."),
        ("Logic Checkpoint", "Has your brain done any heavy lifting today? Thought not."),
    ]

    private let streakAtRiskMessages: [(title: String, body: String)] = [
        ("Streak SOS", "Your streak is crying in the corner. Don't make it worse."),
        ("Streak Alert", "Your streak is hanging by a thread!"),
        ("Emergency", "Your streak called. It's considering other players."),
        ("Don't Break the Chain", "Your streak has trust issues now. Prove it wrong!"),
        ("Streak Therapy Needed", "Your streak is stress-eating. Only you can help."),
    ]

    private let winBackMessages: [(title: String, body: String)] = [
        ("Long Time No See", "Remember us? Your puzzle skills are getting dusty."),
        ("We Saved Your Spot", "The codes are waiting. They've been practicing too."),
        ("Comeback Time", "Your brain is on vacation. Time for a staycation with puzzles."),
        ("We Miss You", "The colors miss being arranged by you. Come back!"),
        ("Brain Update Available", "Your problem-solving skills need a refresh. Tap to update."),
        ("Ghost Alert", "You've been ghosting us. The puzzles are taking it personally."),
    ]

    // MARK: - Initialization

    private init() {
        // Load saved preferences
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 19 // Default 7 PM
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0

        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted && self?.notificationsEnabled == true {
                    self?.scheduleNotifications()
                }
            }

            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Scheduling

    func scheduleNotifications() {
        guard notificationsEnabled, isAuthorized else { return }

        // Cancel existing and reschedule
        cancelAllNotifications()

        scheduleDailyReminder()
        scheduleStreakAtRiskNotification()
    }

    private func scheduleDailyReminder() {
        let message = dailyReminderMessages.randomElement()!

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }

        #if DEBUG
        print("Scheduled daily reminder for \(reminderHour):\(String(format: "%02d", reminderMinute))")
        #endif
    }

    private func scheduleStreakAtRiskNotification() {
        // Schedule for 8 PM if user hasn't played today
        let message = streakAtRiskMessages.randomElement()!

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: NotificationID.streakAtRisk,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule streak notification: \(error)")
            }
        }
    }

    func scheduleWinBackNotification(daysFromNow: Int = 3) {
        guard notificationsEnabled, isAuthorized else { return }

        // Cancel any existing win-back notification
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.winBack])

        let message = winBackMessages.randomElement()!

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(daysFromNow * 24 * 60 * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.winBack,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule win-back notification: \(error)")
            }
        }

        #if DEBUG
        print("Scheduled win-back notification for \(daysFromNow) days from now")
        #endif
    }

    // MARK: - Cancellation

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        clearBadge()
    }

    func cancelStreakNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.streakAtRisk])
    }

    func cancelWinBackNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.winBack])
    }

    // MARK: - Badge Management

    func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        }
    }

    // MARK: - App Lifecycle Integration

    /// Call this when the user plays a game
    func userDidPlay() {
        defaults.set(Date(), forKey: Keys.lastPlayedDate)

        // Cancel streak-at-risk for today since user played
        cancelStreakNotification()

        // Cancel win-back since user is active
        cancelWinBackNotification()

        // Reschedule notifications fresh
        if notificationsEnabled {
            scheduleNotifications()
        }

        clearBadge()
    }

    /// Call this when the app enters background
    func appDidEnterBackground() {
        if notificationsEnabled && isAuthorized {
            // Schedule a win-back notification in case user doesn't return
            scheduleWinBackNotification(daysFromNow: 3)
        }
    }

    /// Call this when the app becomes active
    func appDidBecomeActive() {
        clearBadge()
        checkAuthorizationStatus()

        // Cancel win-back since user is back
        cancelWinBackNotification()
    }

    // MARK: - Formatted Time

    var formattedReminderTime: String {
        let hour = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        let period = reminderHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour, reminderMinute, period)
    }
}
