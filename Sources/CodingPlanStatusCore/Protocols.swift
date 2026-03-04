import Foundation

public protocol ProviderAdapter: Sendable {
    var providerID: ProviderID { get }
    func validateCredential() async throws -> CredentialValidationResult
    func fetchPlanStatus() async throws -> [PlanStatus]
}

public protocol AlertEventStore: Sendable {
    func latestEvent(for dedupeKey: String) async throws -> AlertEvent?
    func upsert(event: AlertEvent) async throws
}

public protocol SnapshotStore: Sendable {
    func save(statuses: [PlanStatus], rawPayloadByPlanID: [String: Data]) async throws
    func latestStatuses() async throws -> [PlanStatus]
    func saveDailyEOD(statuses: [PlanStatus], day: Date) async throws
    func prune(olderThan cutoff: Date) async throws
}

public protocol CredentialStore: Sendable {
    func read(service: String, account: String) throws -> String?
    func write(service: String, account: String, value: String) throws
    func delete(service: String, account: String) throws
}

public protocol UsageClock: Sendable {
    var now: Date { get }
}

public struct SystemClock: UsageClock {
    public var now: Date { Date() }
    public init() {}
}
