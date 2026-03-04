import Foundation
@testable import CodingPlanStatusProviders
@testable import CodingPlanStatusCore

#if canImport(Testing)
import Testing

@Test
func miniMAXMappingFromModelRemains() async throws {
    let payload = """
    {
      "model_remains": [
        {
          "model_name": "MiniMax-M1",
          "current_interval_usage_count": 120,
          "current_interval_total_count": 400,
          "end_time": "2026-03-30T12:00:00Z",
          "remains_time": 3600000
        }
      ]
    }
    """.data(using: .utf8)!

    let client = MockHTTPClient(data: payload, statusCode: 200)
    let adapter = MiniMAXAdapter(
        config: MiniMAXProviderConfig(
            baseURL: URL(string: "https://www.minimaxi.com")!,
            token: "token",
            groupId: "group",
            accountId: "acc"
        ),
        httpClient: client
    )

    let statuses = try await adapter.fetchPlanStatus()
    #expect(statuses.count == 1)
    #expect(statuses[0].planId == "MiniMax-M1")
    #expect(statuses[0].usedPercent == 70)
    #expect(statuses[0].remainingUnit == "times")
}

@Test
func glmFallbackComputesPercentFromTotalAndRemaining() async throws {
    let payload = """
    {
      "data": {
        "plans": [
          {
            "plan_id": "p1",
            "plan_name": "Pro",
            "total": 1000,
            "remaining": 250,
            "reset_at": "2026-03-31T00:00:00Z",
            "unit": "tokens"
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let client = MockHTTPClient(data: payload, statusCode: 200)
    let adapter = GLMAdapter(
        config: GLMProviderConfig(
            baseURL: URL(string: "https://api.z.ai")!,
            token: "raw-token",
            accountId: "acc"
        ),
        httpClient: client
    )

    let statuses = try await adapter.fetchPlanStatus()
    #expect(statuses.count == 1)
    #expect(statuses[0].planId == "p1")
    #expect(Int(statuses[0].usedPercent.rounded()) == 75)
    #expect(statuses[0].remainingUnit == "tokens")
}

#elseif canImport(XCTest)
import XCTest

final class ProviderMappingTests: XCTestCase {
    func testMiniMAXMappingFromModelRemains() async throws {
        let payload = """
        {
          "model_remains": [
            {
              "model_name": "MiniMax-M1",
              "current_interval_usage_count": 120,
              "current_interval_total_count": 400,
              "end_time": "2026-03-30T12:00:00Z",
              "remains_time": 3600000
            }
          ]
        }
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: payload, statusCode: 200)
        let adapter = MiniMAXAdapter(
            config: MiniMAXProviderConfig(
                baseURL: URL(string: "https://www.minimaxi.com")!,
                token: "token",
                groupId: "group",
                accountId: "acc"
            ),
            httpClient: client
        )

        let statuses = try await adapter.fetchPlanStatus()
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].planId, "MiniMax-M1")
        XCTAssertEqual(statuses[0].usedPercent, 70)
        XCTAssertEqual(statuses[0].remainingUnit, "times")
    }

    func testGLMFallbackComputesPercentFromTotalAndRemaining() async throws {
        let payload = """
        {
          "data": {
            "plans": [
              {
                "plan_id": "p1",
                "plan_name": "Pro",
                "total": 1000,
                "remaining": 250,
                "reset_at": "2026-03-31T00:00:00Z",
                "unit": "tokens"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: payload, statusCode: 200)
        let adapter = GLMAdapter(
            config: GLMProviderConfig(
                baseURL: URL(string: "https://api.z.ai")!,
                token: "raw-token",
                accountId: "acc"
            ),
            httpClient: client
        )

        let statuses = try await adapter.fetchPlanStatus()
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].planId, "p1")
        XCTAssertEqual(Int(statuses[0].usedPercent.rounded()), 75)
        XCTAssertEqual(statuses[0].remainingUnit, "tokens")
    }
}
#endif

struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    func get(url: URL, headers: [String : String], queryItems: [URLQueryItem]) async throws -> HTTPResponse {
        if !(200...299).contains(statusCode) {
            throw HTTPClientError.status(statusCode, data)
        }
        return HTTPResponse(statusCode: statusCode, data: data)
    }
}
