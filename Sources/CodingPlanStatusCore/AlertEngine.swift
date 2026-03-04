import Foundation

public actor AlertEngine {
    private let config: ThresholdConfig
    private let store: any AlertEventStore

    public init(config: ThresholdConfig, store: any AlertEventStore) {
        self.config = config
        self.store = store
    }

    public func evaluate(statuses: [PlanStatus], now: Date = Date()) async throws -> [AlertNotification] {
        var notifications: [AlertNotification] = []

        for status in statuses {
            for threshold in config.levels {
                let dedupeKey = dedupeKeyFor(status: status, threshold: threshold)
                let existing = try await store.latestEvent(for: dedupeKey)
                let shouldTrigger = try shouldTrigger(status: status, threshold: threshold, existing: existing, now: now)

                if shouldTrigger {
                    let event = AlertEvent(dedupeKey: dedupeKey, threshold: threshold, triggeredAt: now, clearedAt: nil)
                    try await store.upsert(event: event)
                    notifications.append(
                        AlertNotification(
                            dedupeKey: dedupeKey,
                            provider: status.provider,
                            accountId: status.accountId,
                            planId: status.planId,
                            threshold: threshold,
                            usedPercent: status.usedPercent
                        )
                    )
                } else if let existing, status.usedPercent <= Double(threshold - config.rearmDropPercent), existing.clearedAt == nil {
                    let cleared = AlertEvent(dedupeKey: dedupeKey, threshold: threshold, triggeredAt: existing.triggeredAt, clearedAt: now)
                    try await store.upsert(event: cleared)
                }
            }
        }

        return notifications
    }

    private func shouldTrigger(status: PlanStatus, threshold: Int, existing: AlertEvent?, now: Date) throws -> Bool {
        guard status.usedPercent >= Double(threshold) else {
            return false
        }

        guard let existing else {
            return true
        }

        let dedupeWindow = TimeInterval(config.dedupeHours * 3600)
        let inDedupeWindow = now.timeIntervalSince(existing.triggeredAt) < dedupeWindow

        if existing.clearedAt == nil {
            return false
        }

        if inDedupeWindow {
            return false
        }

        return true
    }

    private func dedupeKeyFor(status: PlanStatus, threshold: Int) -> String {
        "\(status.provider.rawValue)|\(status.accountId)|\(status.planId)|\(threshold)"
    }
}
