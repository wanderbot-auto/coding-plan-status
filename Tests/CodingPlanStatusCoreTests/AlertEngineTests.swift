import Foundation
@testable import CodingPlanStatusCore

#if canImport(Testing)
import Testing

@Test
func triggersAtThreshold() async throws {
    let store = MemoryAlertStore()
    let engine = AlertEngine(config: ThresholdConfig(levels: [80, 90, 95], rearmDropPercent: 5, dedupeHours: 24), store: store)

    let status = PlanStatus(
        provider: .glm,
        accountId: "a",
        planId: "p",
        usedPercent: 91,
        remaining: 10,
        remainingUnit: "times",
        resetAt: nil,
        fetchedAt: Date(),
        severity: .warning
    )

    let alerts = try await engine.evaluate(statuses: [status], now: Date())
    #expect(alerts.count == 2)
    #expect(alerts.map(\.threshold).sorted() == [80, 90])
}

@Test
func rearmNeedsDropBelowThresholdMinusFive() async throws {
    let store = MemoryAlertStore()
    let engine = AlertEngine(config: ThresholdConfig(levels: [90], rearmDropPercent: 5, dedupeHours: 24), store: store)
    let now = Date()

    let high = PlanStatus(
        provider: .glm,
        accountId: "a",
        planId: "p",
        usedPercent: 92,
        remaining: 0,
        remainingUnit: "times",
        resetAt: nil,
        fetchedAt: now,
        severity: .warning
    )
    _ = try await engine.evaluate(statuses: [high], now: now)

    let slightDrop = PlanStatus(
        provider: .glm,
        accountId: "a",
        planId: "p",
        usedPercent: 87,
        remaining: 0,
        remainingUnit: "times",
        resetAt: nil,
        fetchedAt: now,
        severity: .warning
    )
    _ = try await engine.evaluate(statuses: [slightDrop], now: now.addingTimeInterval(60))

    let riseAgain = PlanStatus(
        provider: .glm,
        accountId: "a",
        planId: "p",
        usedPercent: 91,
        remaining: 0,
        remainingUnit: "times",
        resetAt: nil,
        fetchedAt: now,
        severity: .warning
    )
    let secondAlerts = try await engine.evaluate(statuses: [riseAgain], now: now.addingTimeInterval(120))
    #expect(secondAlerts.isEmpty)

    let fullDrop = PlanStatus(
        provider: .glm,
        accountId: "a",
        planId: "p",
        usedPercent: 84,
        remaining: 0,
        remainingUnit: "times",
        resetAt: nil,
        fetchedAt: now,
        severity: .ok
    )
    _ = try await engine.evaluate(statuses: [fullDrop], now: now.addingTimeInterval(180))

    let afterWindow = try await engine.evaluate(statuses: [riseAgain], now: now.addingTimeInterval(25 * 3600))
    #expect(afterWindow.count == 1)
    #expect(afterWindow.first?.threshold == 90)
}

#elseif canImport(XCTest)
import XCTest

final class AlertEngineTests: XCTestCase {
    func testTriggersAtThreshold() async throws {
        let store = MemoryAlertStore()
        let engine = AlertEngine(config: ThresholdConfig(levels: [80, 90, 95], rearmDropPercent: 5, dedupeHours: 24), store: store)

        let status = PlanStatus(
            provider: .glm,
            accountId: "a",
            planId: "p",
            usedPercent: 91,
            remaining: 10,
            remainingUnit: "times",
            resetAt: nil,
            fetchedAt: Date(),
            severity: .warning
        )

        let alerts = try await engine.evaluate(statuses: [status], now: Date())
        XCTAssertEqual(alerts.count, 2)
        XCTAssertEqual(alerts.map(\.threshold).sorted(), [80, 90])
    }

    func testRearmNeedsDropBelowThresholdMinusFive() async throws {
        let store = MemoryAlertStore()
        let engine = AlertEngine(config: ThresholdConfig(levels: [90], rearmDropPercent: 5, dedupeHours: 24), store: store)
        let now = Date()

        let high = PlanStatus(
            provider: .glm,
            accountId: "a",
            planId: "p",
            usedPercent: 92,
            remaining: 0,
            remainingUnit: "times",
            resetAt: nil,
            fetchedAt: now,
            severity: .warning
        )
        _ = try await engine.evaluate(statuses: [high], now: now)

        let slightDrop = PlanStatus(
            provider: .glm,
            accountId: "a",
            planId: "p",
            usedPercent: 87,
            remaining: 0,
            remainingUnit: "times",
            resetAt: nil,
            fetchedAt: now,
            severity: .warning
        )
        _ = try await engine.evaluate(statuses: [slightDrop], now: now.addingTimeInterval(60))

        let riseAgain = PlanStatus(
            provider: .glm,
            accountId: "a",
            planId: "p",
            usedPercent: 91,
            remaining: 0,
            remainingUnit: "times",
            resetAt: nil,
            fetchedAt: now,
            severity: .warning
        )
        let secondAlerts = try await engine.evaluate(statuses: [riseAgain], now: now.addingTimeInterval(120))
        XCTAssertTrue(secondAlerts.isEmpty)

        let fullDrop = PlanStatus(
            provider: .glm,
            accountId: "a",
            planId: "p",
            usedPercent: 84,
            remaining: 0,
            remainingUnit: "times",
            resetAt: nil,
            fetchedAt: now,
            severity: .ok
        )
        _ = try await engine.evaluate(statuses: [fullDrop], now: now.addingTimeInterval(180))

        let afterWindow = try await engine.evaluate(statuses: [riseAgain], now: now.addingTimeInterval(25 * 3600))
        XCTAssertEqual(afterWindow.count, 1)
        XCTAssertEqual(afterWindow.first?.threshold, 90)
    }
}
#endif

actor MemoryAlertStore: AlertEventStore {
    private var map: [String: AlertEvent] = [:]

    func latestEvent(for dedupeKey: String) async throws -> AlertEvent? {
        map[dedupeKey]
    }

    func upsert(event: AlertEvent) async throws {
        map[event.dedupeKey] = event
    }
}
