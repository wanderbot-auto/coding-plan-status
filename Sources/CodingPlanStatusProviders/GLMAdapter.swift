import Foundation
import CodingPlanStatusCore

public struct GLMAdapter: ProviderAdapter {
    public let providerID: ProviderID = .glm

    private let config: GLMProviderConfig
    private let httpClient: any HTTPClient

    public init(config: GLMProviderConfig, httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.config = config
        self.httpClient = httpClient
    }

    public func validateCredential() async throws -> CredentialValidationResult {
        do {
            _ = try await fetchQuotaLimitPayload()
            return CredentialValidationResult(isValid: true, message: nil)
        } catch {
            return CredentialValidationResult(isValid: false, message: error.localizedDescription)
        }
    }

    public func fetchPlanStatus() async throws -> [PlanStatus] {
        let payload = try await fetchQuotaLimitPayload()
        guard let dict = try ProviderMappingSupport.parseJSON(payload) as? [String: Any] else {
            throw ProviderError.invalidPayload("GLM quota payload is not an object")
        }

        let plans = extractPlanDicts(dict)
        if plans.isEmpty {
            let mapped = try mapPlan(from: dict, fallbackPlanID: "glm-default")
            return [mapped]
        }

        return try plans.enumerated().map { index, planDict in
            try mapPlan(from: planDict, fallbackPlanID: "glm-\(index)")
        }
    }

    private func fetchQuotaLimitPayload() async throws -> Data {
        let url = config.baseURL.appending(path: "api/monitor/usage/quota/limit")
        do {
            let response = try await httpClient.get(
                url: url,
                headers: [
                    "Authorization": config.token,
                    "Accept": "application/json"
                ],
                queryItems: []
            )
            return response.data
        } catch let error as HTTPClientError {
            switch error {
            case .status(let code, _):
                if code == 401 {
                    throw ProviderError.invalidCredential("GLM token invalid or unauthorized")
                }
                throw ProviderError.network("GLM quota request failed with status \(code)")
            case .transport(let msg):
                throw ProviderError.network("GLM network error: \(msg)")
            default:
                throw ProviderError.network("GLM request failed")
            }
        }
    }

    private func extractPlanDicts(_ dict: [String: Any]) -> [[String: Any]] {
        let candidates = [
            ["data", "plans"],
            ["data", "plan_limits"],
            ["data", "limits"],
            ["plans"],
            ["plan_limits"],
            ["limits"]
        ]

        for path in candidates {
            if let array = ProviderMappingSupport.nestedValue(in: dict, path: path) as? [[String: Any]], array.isEmpty == false {
                return array
            }
        }

        return []
    }

    private func mapPlan(from dict: [String: Any], fallbackPlanID: String) throws -> PlanStatus {
        let totalCandidates: [[String]] = [
            ["current_interval_total_count"],
            ["total"],
            ["quota_total"],
            ["time_limit_total"],
            ["limit", "total"]
        ]
        let remainingCandidates: [[String]] = [
            ["current_interval_usage_count"],
            ["remaining"],
            ["quota_remaining"],
            ["time_limit_remaining"],
            ["limit", "remaining"]
        ]
        let usedPercentCandidates: [[String]] = [
            ["used_percent"],
            ["usage_percent"],
            ["percentage"]
        ]
        let resetCandidates: [[String]] = [
            ["reset_at"],
            ["end_time"],
            ["current_interval_end_time"],
            ["time_limit_reset_at"]
        ]

        let total = totalCandidates.lazy.compactMap { ProviderMappingSupport.double(from: ProviderMappingSupport.nestedValue(in: dict, path: $0)) }.first
        let remaining = remainingCandidates.lazy.compactMap { ProviderMappingSupport.double(from: ProviderMappingSupport.nestedValue(in: dict, path: $0)) }.first

        let usedPercent: Double
        if let fromPayload = usedPercentCandidates.lazy.compactMap({ ProviderMappingSupport.double(from: ProviderMappingSupport.nestedValue(in: dict, path: $0)) }).first {
            usedPercent = fromPayload
        } else if let total, let remaining, total > 0 {
            usedPercent = ((total - remaining) / total) * 100
        } else {
            throw ProviderError.invalidPayload("GLM quota payload misses usage percentage and total/remaining")
        }

        let planId = (dict["plan_id"] as? String) ?? (dict["id"] as? String) ?? fallbackPlanID
        let planName = (dict["plan_name"] as? String) ?? (dict["name"] as? String) ?? "GLM Plan"
        let remainingValue = Decimal(remaining ?? 0)
        let unit = (dict["unit"] as? String) ?? "quota"
        let resetAt = resetCandidates.lazy.compactMap { ProviderMappingSupport.dateFromISO(ProviderMappingSupport.nestedValue(in: dict, path: $0)) }.first

        return PlanStatus(
            provider: .glm,
            accountId: config.accountId,
            planId: planId,
            planName: planName,
            usedPercent: max(0, min(100, usedPercent)),
            remaining: remainingValue,
            remainingUnit: unit,
            resetAt: resetAt,
            fetchedAt: Date(),
            severity: ProviderMappingSupport.severity(usedPercent: usedPercent)
        )
    }
}
