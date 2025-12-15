import Foundation
import UserNotifications

// MARK: - Notification Manager

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let lastPlayedDate = "lastPlayedForNotifications"
    }
    
    // Notification identifiers
    private enum NotificationID {
        static let dailyReminder = "dailyReminder"
        static let livesFullReminder = "livesFullReminder"
        static let comeBackReminder = "comeBackReminder"
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
                self?.checkAuthorizationStatus()
                
                if granted {
                    self?.scheduleNotifications()
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                
                if settings.authorizationStatus == .authorized {
                    self?.scheduleNotifications()
                }
            }
        }
    }
    
    // MARK: - Scheduling Notifications
    
    func scheduleNotifications() {
        guard authorizationStatus == .authorized else { return }
        
        // Cancel all existing notifications first
        center.removeAllPendingNotificationRequests()
        
        scheduleDailyReminder()
        scheduleLivesFullReminder()
        scheduleComeBackReminder()
    }
    
    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge Available!"
        content.body = "A new daily challenge is waiting for you. Can you crack the code?"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 9 AM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleLivesFullReminder() {
        // This will be called when lives regenerate to max
        let content = UNMutableNotificationContent()
        content.title = "Lives Restored!"
        content.body = "Your lives are full. Time to break some codes!"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 30 minutes from now (this is just a placeholder)
        // In reality, this should be scheduled when the last life regenerates
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.livesFullReminder,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling lives full reminder: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleComeBackReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Missing You!"
        content.body = "Come back and continue your code-breaking streak!"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 3 days after last play
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.comeBackReminder,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling come back reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Actions
    
    func userDidPlay() {
        defaults.set(Date(), forKey: Keys.lastPlayedDate)
        
        // Reschedule come back reminder
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.comeBackReminder])
        scheduleComeBackReminder()
        
        // Clear badge
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - App Lifecycle
    
    func appDidBecomeActive() {
        checkAuthorizationStatus()
        
        // Clear badge when app opens
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    func appDidEnterBackground() {
        // Update notifications based on current state
        scheduleNotifications()
    }
    
    // MARK: - Cancel Notifications
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        // Handle different notification types
        switch identifier {
        case NotificationID.dailyReminder:
            // User can navigate to daily challenge
            break
        case NotificationID.livesFullReminder:
            // User can start playing
            break
        case NotificationID.comeBackReminder:
            // User is back!
            break
        default:
            break
        }
        
        completionHandler()
    }
}
