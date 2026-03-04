import Foundation

public struct GLMProviderConfig: Sendable {
    public var baseURL: URL
    public var token: String
    public var accountId: String

    public init(baseURL: URL, token: String, accountId: String) {
        self.baseURL = baseURL
        self.token = token
        self.accountId = accountId
    }
}

public struct MiniMAXProviderConfig: Sendable {
    public var baseURL: URL
    public var token: String
    public var groupId: String
    public var accountId: String

    public init(baseURL: URL, token: String, groupId: String, accountId: String) {
        self.baseURL = baseURL
        self.token = token
        self.groupId = groupId
        self.accountId = accountId
    }
}
