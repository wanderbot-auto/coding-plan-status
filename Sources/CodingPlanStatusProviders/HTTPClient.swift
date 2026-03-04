import Foundation
import CodingPlanStatusCore

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    public var data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol HTTPClient: Sendable {
    func get(url: URL, headers: [String: String], queryItems: [URLQueryItem]) async throws -> HTTPResponse
}

public enum HTTPClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case status(Int, Data)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .status(let code, _):
            return "HTTP status \(code)"
        case .transport(let message):
            return message
        }
    }
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(url: URL, headers: [String: String], queryItems: [URLQueryItem]) async throws -> HTTPResponse {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let finalURL = components.url else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }
            if (200...299).contains(httpResponse.statusCode) == false {
                throw HTTPClientError.status(httpResponse.statusCode, data)
            }
            return HTTPResponse(statusCode: httpResponse.statusCode, data: data)
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.transport(error.localizedDescription)
        }
    }
}
