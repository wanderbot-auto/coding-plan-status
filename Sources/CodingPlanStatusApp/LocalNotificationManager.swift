import Foundation
import UserNotifications
import CodingPlanStatusCore

actor LocalNotificationManager {
    private let center: UNUserNotificationCenter?

    init() {
        let isAppBundle = Bundle.main.bundleURL.pathExtension.lowercased() == "app"
        let hasBundleID = Bundle.main.bundleIdentifier?.isEmpty == false
        if isAppBundle && hasBundleID {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
    }

    func requestPermission() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func sendAlert(for alert: AlertNotification) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Coding Plan 用量告警"
        content.body = "\(alert.provider.rawValue.uppercased()) 已达到 \(alert.threshold)%（当前 \(Int(alert.usedPercent))%）"
        content.sound = .default

        let request = UNNotificationRequest(identifier: alert.dedupeKey, content: content, trigger: nil)
        try? await center.add(request)
    }
}
