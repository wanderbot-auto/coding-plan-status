import Foundation
import UserNotifications
import Combine
import CodingPlanStatusCore
import CodingPlanStatusProviders
import CodingPlanStatusStorage

@MainActor
final class AppState: ObservableObject {
    @Published var providerSummaries: [ProviderSummary] = ProviderID.allCases.map { ProviderSummary(provider: $0, status: nil) }
    @Published var latestStatuses: [PlanStatus] = []
    @Published var lastRefreshAt: Date?
    @Published var lastErrorMessage: String?

    @Published var glmToken: String = ""
    @Published var minimaxToken: String = ""
    @Published var minimaxGroupId: String = ""

    private let credentialStore: any CredentialStore
    private let snapshotStore: any SnapshotStore
    private let pollingService = PollingService()
    private let alertEngine: AlertEngine
    private let notifications = LocalNotificationManager()
    private let defaults = UserDefaults.standard

    private let retentionDays = 90
    private var hasStarted = false
    private let glmBaseURL = "https://api.z.ai"
    private let minimaxBaseURL = "https://www.minimaxi.com"

    init(
        credentialStore: any CredentialStore,
        snapshotStore: any SnapshotStore,
        alertStore: any AlertEventStore
    ) {
        self.credentialStore = credentialStore
        self.snapshotStore = snapshotStore
        self.alertEngine = AlertEngine(config: ThresholdConfig(levels: [80, 90, 95], rearmDropPercent: 5, dedupeHours: 24), store: alertStore)

        loadCredentials()
    }

    static func makeDefault() -> AppState {
        SharedAppState.instance
    }

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true
        Task {
            await notifications.requestPermission()
            await refreshNow()
            await pollingService.start(intervalSeconds: 300) { [weak self] in
                await self?.refreshNow()
            }
        }
    }

    func stop() {
        Task { await pollingService.stop() }
    }

    func saveCredentials() {
        do {
            let payload = CredentialPayload(glmToken: glmToken, minimaxToken: minimaxToken, minimaxGroupId: minimaxGroupId)
            let data = try JSONEncoder().encode(payload)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "coding-plan-status", code: -1, userInfo: [NSLocalizedDescriptionKey: "凭据编码失败"])
            }
            try credentialStore.write(service: "coding-plan-status", account: "credentials_v1", value: encoded)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "凭据保存失败: \(error.localizedDescription)"
        }
    }

    func refreshNow() async {
        let adapters = buildAdapters()
        var collected: [PlanStatus] = []

        for adapter in adapters {
            do {
                let statuses = try await adapter.fetchPlanStatus()
                collected.append(contentsOf: statuses)
            } catch {
                let errorStatus = PlanStatus(
                    provider: adapter.providerID,
                    accountId: "default",
                    planId: "error",
                    planName: "\(adapter.providerID.rawValue.uppercased())",
                    usedPercent: 0,
                    remaining: 0,
                    remainingUnit: "",
                    resetAt: nil,
                    fetchedAt: Date(),
                    severity: .error
                )
                collected.append(errorStatus)
                lastErrorMessage = "\(adapter.providerID.rawValue) 刷新失败: \(error.localizedDescription)"
            }
        }

        if collected.isEmpty {
            collected = buildUnsupportedStatuses()
        } else {
            let existingProviders = Set(collected.map(\.provider))
            let missingProviders = ProviderID.allCases.filter { existingProviders.contains($0) == false }
            collected.append(contentsOf: missingProviders.map { provider in
                PlanStatus(
                    provider: provider,
                    accountId: "default",
                    planId: "unsupported",
                    planName: "未配置",
                    usedPercent: 0,
                    remaining: 0,
                    remainingUnit: "",
                    resetAt: nil,
                    fetchedAt: Date(),
                    severity: .unsupported
                )
            })
        }

        latestStatuses = collected
        providerSummaries = StatusAggregator.providerSummaries(from: collected)
        lastRefreshAt = Date()

        do {
            try await snapshotStore.save(statuses: collected, rawPayloadByPlanID: [:])
            try await snapshotStore.saveDailyEOD(statuses: collected, day: Date())
            let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
            try await snapshotStore.prune(olderThan: cutoff)

            let alerts = try await alertEngine.evaluate(statuses: collected)
            for alert in alerts {
                await notifications.sendAlert(for: alert)
            }
        } catch {
            lastErrorMessage = "本地存储/告警失败: \(error.localizedDescription)"
        }
    }

    private func loadCredentials() {
        do {
            if let encoded = try credentialStore.read(service: "coding-plan-status", account: "credentials_v1"),
               let data = encoded.data(using: .utf8) {
                let payload = try JSONDecoder().decode(CredentialPayload.self, from: data)
                glmToken = payload.glmToken
                minimaxToken = payload.minimaxToken
                minimaxGroupId = payload.minimaxGroupId
                return
            }

            try migrateLegacyCredentialsIfNeeded()
        } catch {
            lastErrorMessage = "读取凭据失败: \(error.localizedDescription)"
        }
    }

    private func buildAdapters() -> [any ProviderAdapter] {
        var adapters: [any ProviderAdapter] = []

        if glmToken.isEmpty == false, let baseURL = URL(string: glmBaseURL) {
            let config = GLMProviderConfig(baseURL: baseURL, token: glmToken, accountId: "glm-personal")
            adapters.append(GLMAdapter(config: config))
        }

        if minimaxToken.isEmpty == false, minimaxGroupId.isEmpty == false, let baseURL = URL(string: minimaxBaseURL) {
            let config = MiniMAXProviderConfig(baseURL: baseURL, token: minimaxToken, groupId: minimaxGroupId, accountId: "minimax-personal")
            adapters.append(MiniMAXAdapter(config: config))
        }

        return adapters
    }

    private func buildUnsupportedStatuses() -> [PlanStatus] {
        ProviderID.allCases.map { provider in
            PlanStatus(
                provider: provider,
                accountId: "default",
                planId: "unsupported",
                planName: "未配置",
                usedPercent: 0,
                remaining: 0,
                remainingUnit: "",
                resetAt: nil,
                fetchedAt: Date(),
                severity: .unsupported
            )
        }
    }

    private func migrateLegacyCredentialsIfNeeded() throws {
        if defaults.bool(forKey: "legacy_credentials_migration_attempted") {
            return
        }
        defaults.set(true, forKey: "legacy_credentials_migration_attempted")

        let legacyGLMToken = try credentialStore.read(service: "coding-plan-status", account: "glm_token") ?? ""
        let legacyMiniMAXToken = try credentialStore.read(service: "coding-plan-status", account: "minimax_token") ?? ""
        let legacyMiniMAXGroup = try credentialStore.read(service: "coding-plan-status", account: "minimax_group") ?? ""

        let hasLegacy = legacyGLMToken.isEmpty == false || legacyMiniMAXToken.isEmpty == false || legacyMiniMAXGroup.isEmpty == false
        guard hasLegacy else { return }

        glmToken = legacyGLMToken
        minimaxToken = legacyMiniMAXToken
        minimaxGroupId = legacyMiniMAXGroup
        saveCredentials()
    }
}

private struct CredentialPayload: Codable {
    var glmToken: String
    var minimaxToken: String
    var minimaxGroupId: String
}

@MainActor
private enum SharedAppState {
    static let instance: AppState = {
        let credentialStore = KeychainCredentialStore()
        if let sqlite = try? SQLiteStore() {
            return AppState(credentialStore: credentialStore, snapshotStore: sqlite, alertStore: sqlite)
        }
        let fallback = InMemoryStore()
        return AppState(credentialStore: credentialStore, snapshotStore: fallback, alertStore: fallback)
    }()
}

actor InMemoryStore: SnapshotStore, AlertEventStore {
    private var latestByKey: [String: PlanStatus] = [:]
    private var events: [String: AlertEvent] = [:]

    func save(statuses: [PlanStatus], rawPayloadByPlanID: [String : Data]) async throws {
        for status in statuses {
            latestByKey[status.id] = status
        }
    }

    func latestStatuses() async throws -> [PlanStatus] {
        Array(latestByKey.values)
    }

    func saveDailyEOD(statuses: [PlanStatus], day: Date) async throws {}

    func prune(olderThan cutoff: Date) async throws {}

    func latestEvent(for dedupeKey: String) async throws -> AlertEvent? {
        events[dedupeKey]
    }

    func upsert(event: AlertEvent) async throws {
        events[event.dedupeKey] = event
    }
}
