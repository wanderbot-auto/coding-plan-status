import Foundation

public enum ProviderID: String, Codable, CaseIterable, Sendable {
    case glm
    case minimax
}

public enum StatusSeverity: Int, Codable, Comparable, Sendable {
    case ok = 0
    case warning = 1
    case critical = 2
    case unsupported = 3
    case error = 4

    public static func < (lhs: StatusSeverity, rhs: StatusSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PlanStatus: Identifiable, Codable, Equatable, Sendable {
    public var provider: ProviderID
    public var accountId: String
    public var planId: String
    public var planName: String?
    public var usedPercent: Double
    public var remaining: Decimal
    public var remainingUnit: String
    public var resetAt: Date?
    public var fetchedAt: Date
    public var severity: StatusSeverity
    public var rawSnapshotVersion: Int

    public var id: String {
        "\(provider.rawValue)|\(accountId)|\(planId)"
    }

    public init(
        provider: ProviderID,
        accountId: String,
        planId: String,
        planName: String? = nil,
        usedPercent: Double,
        remaining: Decimal,
        remainingUnit: String,
        resetAt: Date?,
        fetchedAt: Date,
        severity: StatusSeverity,
        rawSnapshotVersion: Int = 1
    ) {
        self.provider = provider
        self.accountId = accountId
        self.planId = planId
        self.planName = planName
        self.usedPercent = usedPercent
        self.remaining = remaining
        self.remainingUnit = remainingUnit
        self.resetAt = resetAt
        self.fetchedAt = fetchedAt
        self.severity = severity
        self.rawSnapshotVersion = rawSnapshotVersion
    }
}

public struct ThresholdConfig: Codable, Equatable, Sendable {
    public var levels: [Int]
    public var rearmDropPercent: Int
    public var dedupeHours: Int

    public init(levels: [Int] = [80, 90, 95], rearmDropPercent: Int = 5, dedupeHours: Int = 24) {
        self.levels = levels.sorted()
        self.rearmDropPercent = rearmDropPercent
        self.dedupeHours = dedupeHours
    }
}

public struct CredentialValidationResult: Equatable, Sendable {
    public var isValid: Bool
    public var message: String?

    public init(isValid: Bool, message: String?) {
        self.isValid = isValid
        self.message = message
    }
}

public struct AlertNotification: Equatable, Sendable {
    public var dedupeKey: String
    public var provider: ProviderID
    public var accountId: String
    public var planId: String
    public var threshold: Int
    public var usedPercent: Double

    public init(dedupeKey: String, provider: ProviderID, accountId: String, planId: String, threshold: Int, usedPercent: Double) {
        self.dedupeKey = dedupeKey
        self.provider = provider
        self.accountId = accountId
        self.planId = planId
        self.threshold = threshold
        self.usedPercent = usedPercent
    }
}

public struct AlertEvent: Equatable, Sendable {
    public var dedupeKey: String
    public var threshold: Int
    public var triggeredAt: Date
    public var clearedAt: Date?

    public init(dedupeKey: String, threshold: Int, triggeredAt: Date, clearedAt: Date? = nil) {
        self.dedupeKey = dedupeKey
        self.threshold = threshold
        self.triggeredAt = triggeredAt
        self.clearedAt = clearedAt
    }
}

public struct ProviderSummary: Equatable, Sendable {
    public var provider: ProviderID
    public var status: PlanStatus?

    public init(provider: ProviderID, status: PlanStatus?) {
        self.provider = provider
        self.status = status
    }
}
