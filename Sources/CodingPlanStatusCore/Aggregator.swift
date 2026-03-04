import Foundation

public enum StatusAggregator {
    public static func selectHighestRiskPlan(from statuses: [PlanStatus]) -> PlanStatus? {
        statuses.max {
            if $0.severity == $1.severity {
                return $0.usedPercent < $1.usedPercent
            }
            return $0.severity < $1.severity
        }
    }

    public static func providerSummaries(from statuses: [PlanStatus]) -> [ProviderSummary] {
        ProviderID.allCases.map { provider in
            let providerStatuses = statuses.filter { $0.provider == provider }
            return ProviderSummary(provider: provider, status: selectHighestRiskPlan(from: providerStatuses))
        }
    }

    public static func overallSeverity(from statuses: [PlanStatus]) -> StatusSeverity {
        statuses.map(\.severity).max() ?? .ok
    }
}
