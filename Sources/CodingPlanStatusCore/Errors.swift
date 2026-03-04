import Foundation

public enum ProviderError: Error, LocalizedError, Sendable {
    case invalidCredential(String)
    case network(String)
    case unsupported(String)
    case invalidPayload(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredential(let message): return message
        case .network(let message): return message
        case .unsupported(let message): return message
        case .invalidPayload(let message): return message
        case .unknown(let message): return message
        }
    }
}
