import UIKit
import UserNotifications

extension Notification.Name {
    static let pushDeviceTokenReceived = Notification.Name("MoneyManagerPushDeviceTokenReceived")
    static let pushRegistrationFailed = Notification.Name("MoneyManagerPushRegistrationFailed")
    static let pushNotificationOpened = Notification.Name("MoneyManagerPushNotificationOpened")
}

enum PushDeviceTokenStore {
    private static let key = "money-manager.apns-device-token"

    static var current: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum PushEventStore {
    private static let key = "money-manager.pending-push-event"

    static var pending: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum PushDeviceRegistrationStore {
    private static let key = "money-manager.push-device-id"

    static var deviceID: Int? {
        get {
            let value = UserDefaults.standard.integer(forKey: key)
            return value > 0 ? value : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushDeviceTokenStore.current = token
        NotificationCenter.default.post(name: .pushDeviceTokenReceived, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .pushRegistrationFailed, object: error.localizedDescription)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let eventType = response.notification.request.content.userInfo["event_type"] as? String else { return }
        PushEventStore.pending = eventType
        NotificationCenter.default.post(name: .pushNotificationOpened, object: eventType)
    }
}
