import Foundation
import CodingPlanStatusCore

public struct MiniMAXAdapter: ProviderAdapter {
    public let providerID: ProviderID = .minimax

    private let config: MiniMAXProviderConfig
    private let httpClient: any HTTPClient

    public init(config: MiniMAXProviderConfig, httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.config = config
        self.httpClient = httpClient
    }

    public func validateCredential() async throws -> CredentialValidationResult {
        do {
            _ = try await fetchRemainsPayload()
            return CredentialValidationResult(isValid: true, message: nil)
        } catch {
            return CredentialValidationResult(isValid: false, message: error.localizedDescription)
        }
    }

    public func fetchPlanStatus() async throws -> [PlanStatus] {
        let payload = try await fetchRemainsPayload()
        guard let dict = try ProviderMappingSupport.parseJSON(payload) as? [String: Any] else {
            throw ProviderError.invalidPayload("MiniMAX remains payload is not an object")
        }

        let arrayCandidates: [[String]] = [["model_remains"], ["data", "model_remains"]]
        let models = arrayCandidates.lazy.compactMap { ProviderMappingSupport.nestedValue(in: dict, path: $0) as? [[String: Any]] }.first

        guard let models, models.isEmpty == false else {
            throw ProviderError.invalidPayload("MiniMAX payload missing model_remains")
        }

        return models.enumerated().map { index, model in
            mapModelRemain(model, index: index)
        }
    }

    private func fetchRemainsPayload() async throws -> Data {
        let url = config.baseURL.appending(path: "v1/api/openplatform/coding_plan/remains")
        do {
            let response = try await httpClient.get(
                url: url,
                headers: [
                    "Authorization": "Bearer \(config.token)",
                    "Accept": "application/json"
                ],
                queryItems: [URLQueryItem(name: "GroupId", value: config.groupId)]
            )
            return response.data
        } catch let error as HTTPClientError {
            switch error {
            case .status(let code, _):
                if code == 401 {
                    throw ProviderError.invalidCredential("MiniMAX token invalid or unauthorized")
                }
                throw ProviderError.network("MiniMAX request failed with status \(code)")
            case .transport(let msg):
                throw ProviderError.network("MiniMAX network error: \(msg)")
            default:
                throw ProviderError.network("MiniMAX request failed")
            }
        }
    }

    private func mapModelRemain(_ model: [String: Any], index: Int) -> PlanStatus {
        let total = ProviderMappingSupport.double(from: model["current_interval_total_count"]) ?? 0
        let remainingCount = ProviderMappingSupport.double(from: model["current_interval_usage_count"]) ?? 0
        let used = max(total - remainingCount, 0)
        let usedPercent = total > 0 ? round((used / total) * 100) : 0

        let endTime = ProviderMappingSupport.dateFromISO(model["end_time"])
        let remainsTimeMs = ProviderMappingSupport.double(from: model["remains_time"]) ?? 0
        let fallbackResetAt = Date().addingTimeInterval(remainsTimeMs / 1000)

        let planId = (model["model_name"] as? String) ?? "minimax-plan-\(index)"

        return PlanStatus(
            provider: .minimax,
            accountId: config.accountId,
            planId: planId,
            planName: model["model_name"] as? String,
            usedPercent: max(0, min(100, usedPercent)),
            remaining: Decimal(remainingCount),
            remainingUnit: "times",
            resetAt: endTime ?? fallbackResetAt,
            fetchedAt: Date(),
            severity: ProviderMappingSupport.severity(usedPercent: usedPercent)
        )
    }
}
